#![no_std]
#![no_main]

mod ipc;
mod alloc;
mod scheduler;
mod gatekeeper;

use core::panic::PanicInfo;
use spin::Mutex;

struct YmirState {
    boot_sequence_complete: bool,
    active_persona: u8,
}

static STATE: Mutex<YmirState> = Mutex::new(YmirState {
    boot_sequence_complete: false,
    active_persona: 2,
});

static SCHEDULER: Mutex<scheduler::Scheduler> = Mutex::new(scheduler::Scheduler::new());
static GATEKEEPER: Mutex<gatekeeper::HeimdallGate> = Mutex::new(gatekeeper::HeimdallGate::new());

#[no_mangle]
pub extern "C" fn _start() -> ! {
    // 1. Initialize Hardened Memory Allocator
    {
        let mut state = STATE.lock();
        state.boot_sequence_complete = true;
    }

    // 2. Engage Neural-Symbolbic Scheduler
    loop {
        let mut sched = SCHEDULER.lock();
        sched.dispatch();
    }
}

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {} // Ragnarok incinerate
}
