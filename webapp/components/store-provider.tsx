"use client"

import type React from "react"
import { useRef } from "react"
import { configureStore } from "@reduxjs/toolkit"
import { Provider } from "react-redux"
import telemetryReducer from "@/lib/store/telemetry-slice"

export function makeStore() {
  return configureStore({
    reducer: {
      telemetry: telemetryReducer,
    },
  })
}

export type AppStore = ReturnType<typeof makeStore>
export type RootState = ReturnType<AppStore["getState"]>
export type AppDispatch = AppStore["dispatch"]

export function StoreProvider({ children }: { children: React.ReactNode }) {
  const storeRef = useRef<AppStore | null>(null)
  if (!storeRef.current) {
    storeRef.current = makeStore()
  }
  return <Provider store={storeRef.current}>{children}</Provider>
}
