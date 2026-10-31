import { useEffect } from 'react'
import { useDispatch } from 'react-redux'
import { tick, pushEvent, setBridge } from '@/lib/store/telemetry-slice'

export function useBifrost(kernelIp: string = 'localhost') {
  const dispatch = useDispatch()

  useEffect(() => {
    let socket: WebSocket | null = null
    try {
      const isHttps = typeof window !== 'undefined' && window.location.protocol === 'https:'
      const isLocal = kernelIp === 'localhost' || kernelIp === '127.0.0.1'
      // Port and protocol derived from environment or defaults
      const gatewayPort = process.env.NEXT_PUBLIC_STORMRAVEN_GATEWAY_PORT || '8787'
      const wsUrl = isHttps && !isLocal 
        ? `wss://${kernelIp}/ws` 
        : `ws://${kernelIp}:${gatewayPort}/ws`
      // Bifrost auth (issue #10): append gateway token for the /ws handshake
      const token = process.env.NEXT_PUBLIC_STORMRAVEN_GATEWAY_TOKEN
      if (token && token.length > 0) wsUrl += `?token=${encodeURIComponent(token)}`
      socket = new WebSocket(wsUrl)
    } catch {
      dispatch(setBridge('degraded'))
      return
    }

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

    return () => {
      try {
        socket?.close()
      } catch {
        // ignore close errors
      }
    }
  }, [kernelIp, dispatch])
}
