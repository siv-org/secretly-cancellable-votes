import { LeanIMT, LeanIMTHashFunction } from '@zk-kit/lean-imt'

import { chunk, hashLeanIMT, poseidon, xyztObjToArray } from './utils'
import * as ed from '@noble/ed25519'

/**
 * The data stored by the SIV sever for each vote 
 */
interface IEncryptedAndLock {
    encrypted: string;
    lock: boolean;
}

/**
 * The SIV API returns a JSON object with the following structure:
 */
interface ISIVVote {
    auth: string;
    [key: string]: IEncryptedAndLock | string;
}

/**
 * An interface to represent the data we need from the vote
 */
interface IVoteResult {
    option: string 
    encrypted: string 
} 

/**
 * A group of votes by option
 */
interface IGroupedVotes {
    [option: string]: string[]
}

/**
 * Fetch votes from the SIV API
 * @param endpoint - The endpoint to fetch votes from
 * @returns An array of IVoteResult objects
 */
const fetchVotes = async (endpoint: string): Promise<IVoteResult[]> => {
    const res = await fetch(endpoint)

    if (!res.ok) {
        throw new Error(`Failed to fetch votes: ${res.statusText}`)
    }

    const votes = await res.json() as ISIVVote[]

    const encryptedVotes = votes.map(vote => {
        const voteKey = Object.keys(vote).find(key => key !== 'auth')

        if (voteKey && typeof vote[voteKey] === 'object' && 'encrypted' in vote[voteKey] && vote[voteKey]?.encrypted) {
            return {
                option: voteKey,
                encrypted: vote[voteKey].encrypted
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
const hashEncryptedVote = (encrypted: string): bigint => {
    // @ts-expect-error Overriding .ep privatization
    const RP = ed.RistrettoPoint.fromHex(encrypted).ep 

    const chunked = chunk(xyztObjToArray(RP))

    const hash = poseidon([
        poseidon([chunked[0][0], chunked[0][1], chunked[0][2]]),
        poseidon([chunked[1][0], chunked[1][1], chunked[1][2]]),
        poseidon([chunked[2][0], chunked[2][1], chunked[2][2]]),
        poseidon([chunked[3][0], chunked[3][1], chunked[3][2]])
    ])

    return hash 
}

/**
 * Create a Merkle tree for each option
 * @param groupedVotes - A group of votes by option
 * @returns A map of options to Merkle trees
 */
const createMerkleTreesForOptions = (groupedVotes: IGroupedVotes): {[option: string]: LeanIMT} => {
    const merkleTrees: { [option: string]: LeanIMT } = {};
    
    Object.entries(groupedVotes).forEach(([option, votes]) => {
        // Create merkle tree for this option
        const merkleTree = new LeanIMT(
            hashLeanIMT as unknown as LeanIMTHashFunction,
            votes.map(vote => hashEncryptedVote(vote))
        );

        merkleTrees[option] = merkleTree;
        
        console.log(`Created Merkle tree for ${option} with ${votes.length} votes`);
    });
    
    return merkleTrees;
};

/**
 * Generate one merkle tree for each option and its votes 
 *  1. Get array of all votes, eg from a JSON endpoint
 *  2. Extract `encrypted` field from each vote
 *  3. Chunk the encrypted field 
 * @param endpoint - The endpoint to fetch votes from
 */
export const genMerkleTree = async (endpoint: string): Promise<void> => {
    const votes = await fetchVotes(endpoint)

    // Group votes by option
    const groupedVotes: IGroupedVotes = votes.reduce((acc, vote) => {
        if (!acc[vote.option]) {
            acc[vote.option] = []
        }
        acc[vote.option].push(vote.encrypted)

        return acc
    }, {} as IGroupedVotes)

    const merkleTrees = createMerkleTreesForOptions(groupedVotes)

    Object.entries(merkleTrees).forEach(([option, tree]) => {
        console.log(`Merkle tree for ${option}:`, tree.root)
    })
}

// Example endpoint 
const endpoint = 'https://siv.org/api/election/1752095348369/accepted-votes'

genMerkleTree(endpoint).catch(console.error)
