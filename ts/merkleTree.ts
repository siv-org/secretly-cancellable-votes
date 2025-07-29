import { LeanIMT, LeanIMTHashFunction } from '@zk-kit/lean-imt'
import * as ed from '@noble/ed25519'

import { chunk, hashLeanIMT, poseidon, xyztObjToArray } from './utils'

import type { ISIVVote, IVoteResult, IGroupedVotes } from './types'

/**
 * Fetch votes from the SIV API
 * @param endpoint - The endpoint to fetch votes from
 * @returns An array of IVoteResult objects
 */
export const fetchVotes = async (endpoint: string): Promise<IVoteResult[]> => {
  const res = await fetch(endpoint)

  if (!res.ok) {
    throw new Error(`Failed to fetch votes: ${res.statusText}`)
  }

  const votes = (await res.json()) as ISIVVote[]

  const encryptedVotes = votes.map((vote) => {
    const voteKey = Object.keys(vote).find((key) => key !== 'auth')

    if (
      voteKey &&
      typeof vote[voteKey] === 'object' &&
      'encrypted' in vote[voteKey] &&
      vote[voteKey]?.encrypted
    ) {
      return {
        option: voteKey,
        encrypted: vote[voteKey].encrypted,
      }
    }

    throw new Error(`No encrypted data found for vote with auth: ${vote.auth}`)
  })

  return encryptedVotes
}

/**
 * Take an encrypted vote and hash it
 * @dev To hash a Ristretto Point, which is a 4x3 array of arrays:
 *      [[1, 2, 3], [4, 5, 6], [7, 8, 9], [10, 11, 12]]
 *      hash4(hash3([1,2,3]), hash3([4,5,6]), hash3([7,8,9]), hash3([10,11,12]))
 * @param encrypted -The encrypted vote
 * @returns The hash of the encrypted vote
 */
export const hashEncryptedVote = (encrypted: string): bigint => {
  // @ts-expect-error Overriding .ep privatization
  const RP = ed.RistrettoPoint.fromHex(encrypted).ep

  const chunked = chunk(xyztObjToArray(RP))

  const hash = poseidon([
    poseidon([chunked[0][0], chunked[0][1], chunked[0][2]]),
    poseidon([chunked[1][0], chunked[1][1], chunked[1][2]]),
    poseidon([chunked[2][0], chunked[2][1], chunked[2][2]]),
    poseidon([chunked[3][0], chunked[3][1], chunked[3][2]]),
  ])

  return hash
}

/**
 * Create a Merkle tree for each option
 * @param groupedVotes - A group of votes by option
 * @returns A map of options to Merkle trees
 */
export const createMerkleTreesForOptions = (
  groupedVotes: IGroupedVotes
): { [option: string]: LeanIMT } => {
  const merkleTrees: { [option: string]: LeanIMT } = {}

  Object.entries(groupedVotes).forEach(([option, votes]) => {
    // Create merkle tree for this option
    const merkleTree = new LeanIMT(
      hashLeanIMT as unknown as LeanIMTHashFunction,
      votes.map((vote) => hashEncryptedVote(vote))
    )

    merkleTrees[option] = merkleTree
  })

  return merkleTrees
}

export const groupVotesByOption = (votes: IVoteResult[]): IGroupedVotes => {
  // Group votes by option
  return votes.reduce((acc, vote) => {
    if (!acc[vote.option]) {
      acc[vote.option] = []
    }
    acc[vote.option].push(vote.encrypted)

    return acc
  }, {} as IGroupedVotes)
}

/**
 * Generate one merkle tree for each option and its votes
 *  1. Get array of all votes, eg from a JSON endpoint
 *  2. Extract `encrypted` field from each vote
 *  3. Chunk the encrypted field
 * @param endpoint - The endpoint to fetch votes from
 */
export const genMerkleTree = async (
  endpoint: string
): Promise<{ [option: string]: LeanIMT }> => {
  const votes = await fetchVotes(endpoint)

  const groupedVotes = groupVotesByOption(votes)

  return createMerkleTreesForOptions(groupedVotes)
}

// Example endpoint
// const endpoint = 'https://siv.org/api/election/1752095348369/accepted-votes'

// run it
// genMerkleTree(endpoint).catch(console.error)
