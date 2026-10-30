import { useEffect } from 'react'
import { useDispatch } from 'react-redux'
import { tick, pushEvent, setBridge } from '@/lib/store/telemetry-slice'

export function useBifrost(kernelIp: string = 'localhost') {
  const dispatch = useDispatch()

  useEffect(() => {
    const socket = new WebSocket(`ws://${kernelIp}:8787/ws`)

    socket.onopen = () => {
      dispatch(setBridge('connected'))
      console.log('[Bifröst] Bridge established to', kernelIp)
    }

    socket.onmessage = (event) => {
      const msg = JSON.parse(event.data)
      
      switch (msg.type) {
        case 'health.tick':
          dispatch(tick(msg.data))
          break
        case 'signal':
          dispatch(pushEvent({
            id: Math.random().toString(36).substring(7),
            daemon: msg.data.provider,
            severity: 'info',
            message: `Signal received from ${msg.data.provider}`,
            ts: Date.now()
          }))
          break
        case 'decision':
          dispatch(pushEvent({
            id: msg.data.id,
            daemon: 'kernel',
            severity: msg.data.severity === 'high' ? 'alert' : 'warn',
            message: msg.data.summary,
            ts: Date.now()
          }))
          break
      }
    }

    socket.onclose = () => {
      dispatch(setBridge('offline'))
      console.log('[Bifröst] Bridge closed')
    }

    socket.onerror = () => {
      dispatch(setBridge('degraded'))
    }

    return () => socket.close()
  }, [kernelIp, dispatch])
}
