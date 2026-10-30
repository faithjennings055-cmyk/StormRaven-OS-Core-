import { createSlice, type PayloadAction } from "@reduxjs/toolkit"
import { PANTHEON, type DaemonStatus } from "@/lib/pantheon"

export interface DaemonTelemetry {
  id: string
  status: DaemonStatus
  cpu: number
  mem: number
  threads: number
  lastHeartbeat: number
  events: number
}

export interface BifrostEvent {
  id: string
  daemon: string
  severity: "info" | "warn" | "alert"
  message: string
  ts: number
}

interface TelemetryState {
  daemons: Record<string, DaemonTelemetry>
  feed: BifrostEvent[]
  bridge: "connected" | "degraded" | "offline"
  threatLevel: number
}

const seededAt = Date.now()

const initialState: TelemetryState = {
  daemons: PANTHEON.reduce(
    (acc, d) => {
      acc[d.id] = {
        id: d.id,
        // Non-destructive mandate: scanners/monitors keep their registry default.
        status: d.defaultStatus,
        cpu: d.defaultStatus === "online" ? 4 : 0,
        mem: d.defaultStatus === "online" ? 12 : 0,
        threads: d.id === "demogorgon" ? 0 : d.defaultStatus === "online" ? 4 : 1,
        lastHeartbeat: seededAt,
        events: 0,
      }
      return acc
    },
    {} as Record<string, DaemonTelemetry>,
  ),
  feed: [],
  bridge: "connected",
  threatLevel: 0,
}

const telemetrySlice = createSlice({
  name: "telemetry",
  initialState,
  reducers: {
    tick(state, action: PayloadAction<{ daemons: DaemonTelemetry[]; threatLevel: number }>) {
      for (const d of action.payload.daemons) {
        state.daemons[d.id] = d
      }
      state.threatLevel = action.payload.threatLevel
    },
    pushEvent(state, action: PayloadAction<BifrostEvent>) {
      state.feed.unshift(action.payload)
      if (state.feed.length > 60) state.feed.pop()
      const d = state.daemons[action.payload.daemon]
      if (d) d.events += 1
    },
    setDaemonStatus(state, action: PayloadAction<{ id: string; status: DaemonStatus }>) {
      const d = state.daemons[action.payload.id]
      if (d) {
        d.status = action.payload.status
        if (action.payload.status === "disabled") {
          d.cpu = 0
          d.mem = 0
        }
      }
    },
    setBridge(state, action: PayloadAction<TelemetryState["bridge"]>) {
      state.bridge = action.payload
    },
  },
})

export const { tick, pushEvent, setDaemonStatus, setBridge } = telemetrySlice.actions
export default telemetrySlice.reducer
