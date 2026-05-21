"""
GPUSim — GPU 模拟器顶层 + Kernel Launch + Performance Monitor
===============================================================
对标 GPGPU-Sim 中 gpgpu_sim 顶层类的 kernel launch 和性能统计功能。

Phase 6: 整合 Phase 0-5 的所有模块，提供 CUDA 风格的 grid/block launch。
Phase 6.1: SM 池 + block 分配器 + 多 SM 并行调度。
  - pending_blocks 队列管理待调度 block
  - SM 池 (SM0, SM1, ..., SMN) 并行执行
  - 每个 cycle: 空闲 SM 取 block, 所有 SM 各执行一步
  - block 完成后 SM 释放，再取下一个

参考: GPGPU-Sim gpgpu-sim/gpu-sim.cc 中 gpgpu_sim::launch()
"""
# [phase6_kernel added]

from typing import List, Optional, Tuple
from simt_core import SIMTCore


class PerfCounters:
    """性能计数器

    对应 GPGPU-Sim 的统计模块 (stat-tool)。
    """
    def __init__(self):
        self.total_cycles = 0
        self.total_instructions = 0
        self.stall_scoreboard = 0
        self.stall_barrier = 0
        self.stall_branch = 0
        self.active_cycles = 0

    @property
    def ipc(self) -> float:
        return self.total_instructions / self.total_cycles if self.total_cycles > 0 else 0.0

    def report(self) -> str:
        c = self.total_cycles
        if c == 0: return "No cycles executed"
        return (
            f"Performance Report:\n"
            f"  Total cycles:      {c}\n"
            f"  Total instructions: {self.total_instructions}\n"
            f"  IPC:               {self.ipc:.3f}\n"
            f"  Active cycles:     {self.active_cycles} ({self.active_cycles/c*100:.1f}%)\n"
            f"  Stalls:\n"
            f"    Scoreboard:      {self.stall_scoreboard} ({self.stall_scoreboard/c*100:.1f}%)\n"
            f"    Barrier:         {self.stall_barrier} ({self.stall_barrier/c*100:.1f}%)\n"
        )


# [phase6_kernel added] SM pool + block allocator
class SM:
    """Streaming Multiprocessor — 执行一个 thread block

    对应 GPGPU-Sim 中 shader_core_ctx 的上层 wrapper。
    每个 SM 同一时刻只运行一个 block，block 完成后释放。
    """

    def __init__(self, sm_id: int, warp_size: int = 8, memory_size: int = 1024):
        self.sm_id = sm_id
        self.warp_size = warp_size
        self.memory_size = memory_size
        self.core: Optional[SIMTCore] = None
        self.busy = False
        self.block_id = -1
        self.completed_blocks = 0
        self.total_cycles = 0

    def assign_block(self, block_id: int, program: list, num_warps: int):
        """分配一个 block 到此 SM"""
        self.core = SIMTCore(
            warp_size=self.warp_size,
            num_warps=num_warps,
            memory_size=self.memory_size
        )
        self.core.load_program(program)
        self.busy = True
        self.block_id = block_id

    def step(self) -> bool:
        """执行一个周期。返回 True 表示 SM 仍忙碌（block 未完成）。"""
        if not self.busy or self.core is None:
            return False
        self.total_cycles += 1
        has_active = self.core.step()
        if not has_active:
            self.busy = False
            self.completed_blocks += 1
        return self.busy

    def release(self):
        """手动释放 SM"""
        self.busy = False
        self.block_id = -1


class GPUSim:
    """GPU 模拟器顶层 — SM 池 + block 分配器

    对应 GPGPU-Sim 的 gpgpu_sim 类。

    调度流程:
        pending_blocks 队列
        SM0, SM1, ..., SMN
        每个 cycle:
          空闲 SM 从 pending_blocks 取一个 block
          所有非空闲 SM 各执行一步
          block 完成后 SM 释放，再取下一个 block

    Attributes:
        sms: SM 列表 (SM 池)
        pending_blocks: 待调度的 block 队列
        cores: 兼容旧接口 — 指向所有已创建过的 SIMTCore
        perf: 性能计数器
    """

    def __init__(self, num_sms: int = 1, warp_size: int = 8,
                 memory_size: int = 1024):
        self.num_sms = num_sms
        self.warp_size = warp_size
        self.memory_size = memory_size
        self.sms: List[SM] = [SM(i, warp_size, memory_size) for i in range(num_sms)]
        self.pending_blocks: List[Tuple[int, list, int]] = []  # (block_id, program, num_warps)
        self.cores: List[SIMTCore] = []  # 兼容旧接口
        self.perf = PerfCounters()
        self.total_cycles = 0

    def launch_kernel(self, program: list[int], grid_dim: tuple = (1,),
                      block_dim: tuple = (8,)):
        """启动 kernel（对标 CUDA kernel launch）

        将 block 放入 pending_blocks 队列，等待 SM 调度。

        Args:
            program: 机器码列表
            grid_dim: grid 维度，如 (2,) 表示 2 个 block
            block_dim: block 维度，如 (8,) 表示 8 个线程
        """
        total_blocks = 1
        for d in grid_dim:
            total_blocks *= d
        total_threads = 1
        for d in block_dim:
            total_threads *= d

        num_warps_per_block = max(1, total_threads // self.warp_size)

        for block_id in range(total_blocks):
            self.pending_blocks.append((block_id, list(program), num_warps_per_block))

        print(f"Kernel launched: {total_blocks} block(s) x "
              f"{num_warps_per_block} warp(s) x "
              f"{self.warp_size} threads/warp = "
              f"{total_blocks * num_warps_per_block * self.warp_size} threads "
              f"on {self.num_sms} SM(s)")

    def _assign_idle_sms(self):
        """将空闲 SM 分配给 pending_blocks 队列中的 block"""
        for sm in self.sms:
            if not sm.busy and self.pending_blocks:
                block_id, program, num_warps = self.pending_blocks.pop(0)
                sm.assign_block(block_id, program, num_warps)
                self.cores.append(sm.core)

    def _any_sm_busy(self) -> bool:
        return any(sm.busy for sm in self.sms)

    def run(self, trace: bool = False):
        """SM 池并行调度：每个 cycle 所有 SM 各执行一步

        Args:
            trace: 是否输出每周期 trace 信息
        """
        self.perf = PerfCounters()
        self.total_cycles = 0
        cycle = 0

        while self.pending_blocks or self._any_sm_busy():
            # 空闲 SM 取 block
            self._assign_idle_sms()
            # 新分配的 core 初始化 trace state
            if trace:
                for sm in self.sms:
                    if sm.busy and sm.core and sm.core.instr_count == 0:
                        if not hasattr(sm, '_trace_inited') or not sm._trace_inited:
                            sm.core._update_trace_state()
                            sm._trace_inited = True

            # 所有 SM 执行一步
            for sm in self.sms:
                if sm.busy:
                    sm.step()

            # Trace output
            if trace:
                for sm in self.sms:
                    if sm.busy and sm.core and sm.core._last_warp_id >= 0:
                        sm.core._trace_step(cycle)

            self.total_cycles += 1
            cycle += 1

        if trace:
            total_instr = sum(sm.core.instr_count if sm.core else 0 for sm in self.sms)
            print(f"[Summary] {cycle} cycles, {total_instr} instructions")

        # 收集性能数据
        for sm in self.sms:
            self.perf.total_cycles = max(self.perf.total_cycles, sm.total_cycles)
            if sm.core:
                self.perf.total_instructions += sm.core.instr_count
                self.perf.active_cycles += sm.total_cycles

    def report(self):
        """打印性能报告"""
        print(f"Total cycles: {self.total_cycles}")
        print(f"SM utilization: {self.num_sms} SM(s) used")
        for sm in self.sms:
            status = "completed" if not sm.busy else "busy"
            print(f"  SM{sm.sm_id}: {sm.completed_blocks} block(s), "
                  f"{sm.total_cycles} cycles, {status}")
        print(self.perf.report())
        for i, core in enumerate(self.cores):
            print(f"\nBlock {i}:")
            print(f"  {core.l1_cache.stats()}")
            if core.total_mem_reqs > 0:
                eff = core.coalesce_count / core.total_mem_reqs * 100
                print(f"  Coalescing: {core.coalesce_count}/{core.total_mem_reqs} ({eff:.0f}%)")


def decode_wrapper(word):
    from isa import decode
    return decode(word)
