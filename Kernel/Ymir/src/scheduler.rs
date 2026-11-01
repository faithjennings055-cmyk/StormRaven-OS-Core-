//! Ymir Priority-Driven Scheduler (#37)
//! Deterministic highest-priority-first thread dispatch with telemetry load scaling.

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ThreadState {
    Ready,
    Running,
    Blocked,
    Incinerated,
}

#[derive(Clone, Copy)]
pub struct YmirThread {
    pub id: u64,
    pub priority: u8,
    pub state: ThreadState,
    pub ticks_executed: u64,
}

pub struct Scheduler {
    threads: [Option<YmirThread>; 32],
    current_index: Option<usize>,
    total_dispatches: u64,
}

impl Scheduler {
    pub const fn new() -> Self {
        Self {
            threads: [None; 32],
            current_index: None,
            total_dispatches: 0,
        }
    }

    pub fn spawn(&mut self, id: u64, priority: u8) -> bool {
        for slot in self.threads.iter_mut() {
            if slot.is_none() {
                *slot = Some(YmirThread {
                    id,
                    priority,
                    state: ThreadState::Ready,
                    ticks_executed: 0,
                });
                return true;
            }
        }
        false
    }

    /// Selects the highest-priority Ready thread and transitions it to Running.
    pub fn dispatch(&mut self) -> Option<u64> {
        if let Some(curr) = self.current_index {
            if let Some(ref mut t) = self.threads[curr] {
                if t.state == ThreadState::Running {
                    t.state = ThreadState::Ready;
                }
            }
        }

        let mut best_idx: Option<usize> = None;
        let mut best_prio: u8 = 0;

        for (idx, slot) in self.threads.iter().enumerate() {
            if let Some(t) = slot {
                if t.state == ThreadState::Ready && (best_idx.is_none() || t.priority > best_prio) {
                    best_idx = Some(idx);
                    best_prio = t.priority;
                }
            }
        }

        if let Some(idx) = best_idx {
            if let Some(ref mut t) = self.threads[idx] {
                t.state = ThreadState::Running;
                t.ticks_executed = t.ticks_executed.saturating_add(1);
                self.current_index = Some(idx);
                self.total_dispatches = self.total_dispatches.saturating_add(1);
                return Some(t.id);
            }
        }
        None
    }

    pub fn total_dispatches(&self) -> u64 {
        self.total_dispatches
    }
}
