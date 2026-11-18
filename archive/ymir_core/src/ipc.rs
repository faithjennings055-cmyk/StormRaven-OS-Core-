// src/ipc.rs
// Hardened IPC layer for Ymir Core

pub struct SecureFrame<'a> {
    buffer: &'a mut [u8],
    offset: usize,
}

impl<'a> SecureFrame<'a> {
    pub fn new(buffer: &'a mut [u8]) -> Self {
        Self {
            buffer,
            offset: 0,
        }
    }

    /// Reads a fixed-size window from the buffer with strict bounds checking.
    /// This replaces raw pointer arithmetic to guarantee memory safety.
    pub fn read_window(&mut self, size: usize) -> Result<&[u8], &'static str> {
        if self.offset + size > self.buffer.len() {
            return Err("Buffer overflow: window exceeds frame boundaries");
        }
        let window = &self.buffer[self.offset..self.offset + size];
        self.offset += size;
        Ok(window)
    }

    /// Writes a slice to the buffer with strict bounds checking.
    pub fn write_frame(&mut self, data: &[u8]) -> Result<(), &'static str> {
        if self.offset + data.len() > self.buffer.len() {
            return Err("Buffer overflow: data exceeds frame capacity");
        }
        self.buffer[self.offset..self.offset + data.len()].copy_from_slice(data);
        self.offset += data.len();
        Ok(())
    }

    pub fn reset(&mut self) {
        self.offset = 0;
    }
}
