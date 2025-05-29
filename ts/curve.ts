import { RistrettoPoint as RP } from '@noble/ed25519'
import { randomBytes } from 'crypto'

/** We have 32 bytes to start,
minus the first one for storing length,
minus one more for min random entropy needed to find a valid point. */
export const maxLength = 32 - 2

/** Embed binary data into a valid Ristretto255 point */
function embed(data: Uint8Array): RP {
  const { length } = data
  if (length > maxLength)
    throw new Error(`Too much data to embed: ${length} > ${maxLength}`)

  const maxAttempts = 1000
  for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
    // Fill w/ random bytes
    const bytes = new Uint8Array(randomBytes(32))

    // Store the data's length in the first byte
    // BUT Ristretto needs the first bit to always be off
    // so shift it left by one bit, then undo later
    bytes[0] = length << 1

    bytes.set(data, 1) // Copy in data

    // Now check if it's a valid point
    let point: RP
    try {
      point = RP.fromHex(bytes)
    } catch {
      continue // Invalid point, retry
    }

    // console.log(`Attempts needed to embed: ${attempt + 1}`)

    return point // Success
  }

  throw new Error(`Ran out of embedding attempts: ${maxAttempts}`)
}

/** Embed string data into a Ristretto255 point */
export const stringToPoint = (message: string): RP =>
  embed(new TextEncoder().encode(message))

/** Extract embedded data from a Ristretto255 point */
function extract(point: RP): Uint8Array {
  const bytes = point.toRawBytes()
  const length = bytes[0] >> 1 // Extract length from 1st byte, undoing embed()'s left shift
  if (length > maxLength)
    throw new Error(`extract length ${length} > maxLength ${maxLength}`)
  return bytes.subarray(1, 1 + length)
}

/** Extract string data from a Ristretto255 point */
export const pointToString = (point: RP): string =>
  new TextDecoder().decode(extract(point))
