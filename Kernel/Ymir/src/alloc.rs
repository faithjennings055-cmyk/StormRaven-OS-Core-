//! Ymir Memory Management: Deterministic Bitmap Slab & Buddy Allocator (#37)
//! Engineered for 1% margin — zero unbounded fragmentation, bounds-checked slots.

use core::alloc::{GlobalAlloc, Layout};
use core::ptr;
use spin::Mutex;

const SLAB_SLOT_SIZE: usize = 256;
const SLAB_SLOT_COUNT: usize = 64;
const BUDDY_BLOCK_SIZE: usize = 4096;
const BUDDY_BLOCK_COUNT: usize = 16;

pub struct YmirAllocator {
    slab_bitmap: u64,
    buddy_bitmap: u16,
    slab_pool: [u8; SLAB_SLOT_SIZE * SLAB_SLOT_COUNT],
    buddy_pool: [u8; BUDDY_BLOCK_SIZE * BUDDY_BLOCK_COUNT],
}

impl YmirAllocator {
    pub const fn new() -> Self {
        Self {
            slab_bitmap: 0,
            buddy_bitmap: 0,
            slab_pool: [0; SLAB_SLOT_SIZE * SLAB_SLOT_COUNT],
            buddy_pool: [0; BUDDY_BLOCK_SIZE * BUDDY_BLOCK_COUNT],
        }
    }

    pub fn allocate_slab(&mut self, size: usize) -> *mut u8 {
        if size == 0 || size > SLAB_SLOT_SIZE {
            return ptr::null_mut();
        }
        for idx in 0..SLAB_SLOT_COUNT {
            let mask = 1u64 << idx;
            if (self.slab_bitmap & mask) == 0 {
                self.slab_bitmap |= mask;
                let offset = idx * SLAB_SLOT_SIZE;
                return unsafe { self.slab_pool.as_mut_ptr().add(offset) };
            }
        }
        ptr::null_mut()
    }

    pub fn deallocate_slab(&mut self, ptr: *mut u8) -> bool {
        let base = self.slab_pool.as_ptr() as usize;
        let addr = ptr as usize;
        let end = base + (SLAB_SLOT_SIZE * SLAB_SLOT_COUNT);
        if addr < base || addr >= end || (addr - base) % SLAB_SLOT_SIZE != 0 {
            return false;
        }
        let idx = (addr - base) / SLAB_SLOT_SIZE;
        self.slab_bitmap &= !(1u64 << idx);
        true
    }

    pub fn allocate_buddy(&mut self, layout: Layout) -> *mut u8 {
        let needed_blocks = (layout.size() + BUDDY_BLOCK_SIZE - 1) / BUDDY_BLOCK_SIZE;
        if needed_blocks == 0 || needed_blocks > BUDDY_BLOCK_COUNT {
            return ptr::null_mut();
        }
        for start in 0..=(BUDDY_BLOCK_COUNT - needed_blocks) {
            let mut free = true;
            for b in 0..needed_blocks {
                if (self.buddy_bitmap & (1u16 << (start + b))) != 0 {
                    free = false;
                    break;
                }
            }
            if free {
                for b in 0..needed_blocks {
                    self.buddy_bitmap |= 1u16 << (start + b);
                }
                let offset = start * BUDDY_BLOCK_SIZE;
                return unsafe { self.buddy_pool.as_mut_ptr().add(offset) };
            }
        }
        ptr::null_mut()
    }

    pub fn deallocate_buddy(&mut self, ptr: *mut u8, layout: Layout) -> bool {
        let base = self.buddy_pool.as_ptr() as usize;
        let addr = ptr as usize;
        let end = base + (BUDDY_BLOCK_SIZE * BUDDY_BLOCK_COUNT);
        if addr < base || addr >= end || (addr - base) % BUDDY_BLOCK_SIZE != 0 {
            return false;
        }
        let start = (addr - base) / BUDDY_BLOCK_SIZE;
        let blocks = (layout.size() + BUDDY_BLOCK_SIZE - 1) / BUDDY_BLOCK_SIZE;
        for b in 0..blocks {
            if start + b < BUDDY_BLOCK_COUNT {
                self.buddy_bitmap &= !(1u16 << (start + b));
            }
        }
        true
    }

    pub fn used_slab_slots(&self) -> u32 {
        self.slab_bitmap.count_ones()
    }

    pub fn used_buddy_blocks(&self) -> u32 {
        self.buddy_bitmap.count_ones()
    }
}

pub struct GlobalYmirAllocator(pub Mutex<YmirAllocator>);

unsafe impl GlobalAlloc for GlobalYmirAllocator {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        let mut alloc = self.0.lock();
        if layout.size() <= SLAB_SLOT_SIZE {
            alloc.allocate_slab(layout.size())
        } else {
            alloc.allocate_buddy(layout)
        }
    }

    unsafe fn dealloc(&self, ptr: *mut u8, layout: Layout) {
        let mut alloc = self.0.lock();
        if layout.size() <= SLAB_SLOT_SIZE {
            alloc.deallocate_slab(ptr);
        } else {
            alloc.deallocate_buddy(ptr, layout);
        }
    }
}
