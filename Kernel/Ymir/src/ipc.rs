//! IPC Serialization Layer
//! Designed to eliminate the 'undefined behavior' risks flagged in the 
//! Yorman Gunder evaluation. Focus: Stack-overflow immunity and 
//! strict boundary verification.

use core::ptr;

pub enum IpcError {
    BufferOverflow,
    InvalidPacket,
    SerializationFault,
}

/// A bounds-checked frame for telemetry and command serialization.
/// Replaces raw pointer arithmetic with slice-based windowing.
pub struct SecureFrame<'a> {
    buffer: &'a mut [u8],
    cursor: usize,
}

impl<'a> SecureFrame<'a> {
    pub fn new(buf: &'a mut [u8]) -> Self {
        Self { buffer: buf, cursor: 0 }
    }

    /// Safely writes a u32 to the buffer with strict bounds checking.
    pub fn write_u32(&mut self, value: u32) -> Result<(), IpcError> {
        if self.cursor + 4 > self.buffer.len() {
            return Err(IpcError::BufferOverflow);
        }
        
        let bytes = value.to_be_bytes();
        self.buffer[self.cursor..self.cursor + 4].copy_from_slice(&bytes);
        self.cursor += 4;
        Ok(())
    }

    /// Safely writes a byte slice (e.g., telemetry string) with length prefixing.
    pub fn write_bytes(&mut self, data: &[u8]) -> Result<(), IpcError> {
        // Write length prefix first (u32)
        self.write_u32(data.len() as u32)?;
        
        if self.cursor + data.len() > self.buffer.len() {
            return Err(IpcError::BufferOverflow);
        }
        
        self.buffer[self.cursor..self.cursor + data.len()].copy_from_slice(data);
        self.cursor += data.len();
        Ok(())
    }

    pub fn reset(&mut self) {
        self.cursor = 0;
    }
}
