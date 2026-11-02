import { NextResponse } from "next/server"
export async function GET(_req: Request, ctx: { params: Promise<{ slug: string[] }> }) {
  const { slug } = await ctx.params
  const file = slug?.join("/") || "StormRavenOS-Infinity-Protocol-v3.7.0-amd64.iso"
  return NextResponse.redirect(`https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/iso/${file}`, 307)
}
