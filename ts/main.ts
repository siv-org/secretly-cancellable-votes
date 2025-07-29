import process from "process"
import { groth16, type CircuitSignals } from "snarkjs"
import { LeanIMT, type LeanIMTHashFunction } from "@zk-kit/lean-imt"
import * as ed from "@noble/ed25519"

import { fetchVotes, groupVotesByOption, hashEncryptedVote } from "./merkleTree"
import { bigintTo255Bits, chunk, cleanThreads, hashLeanIMT, readConfig, TREE_DEPTH, xyztObjToArray } from "./utils"
import { ElectionType, ICircuitInputs } from "./types"

// Inputs
const configPath = process.argv[2] || "./config.json"

export const main = async () => {
    // 1. read the config 
    const config = readConfig(configPath)
    const { zKeyPath, wasmPath, electionPublicKey, adminSecretSalt, voteSecretRandomizer, encodedVoteToCancel, endpoint, electionType } = config

    let { questionId } = config

    if (electionType === ElectionType.ChooseOnlyOne) {
        questionId = "item"
    } else {
        if (!questionId) {
            throw new Error("Option is required for ranked choice elections")
        }
    }

    const electionPubKey = ed.RistrettoPoint.fromHex(electionPublicKey)
    // @ts-expect-error Overriding .ep privatization
    const chunkedElectionPubKey = chunk(xyztObjToArray(electionPubKey.ep))

    const encodedVoteAsPoint = ed.RistrettoPoint.fromHex(encodedVoteToCancel)
    // @ts-expect-error Overriding .ep privatization
    const encodedVoteToCancelChunked = chunk(xyztObjToArray(encodedVoteAsPoint.ep))

    const jsEncryptedVoteToCancel = encodedVoteAsPoint.add(electionPubKey.multiply(BigInt(voteSecretRandomizer)))

    const jsEncryptedVoteToCancelHex = ed.RistrettoPoint.fromHex(jsEncryptedVoteToCancel.toHex())

    // @ts-expect-error Overriding .ep privatization
    const jsEncryptedVoteToCancelChunked = chunk(xyztObjToArray(jsEncryptedVoteToCancelHex.ep))

    // 2. fetch the votes from the SIV API
    const votes = await fetchVotes(endpoint)

    // 3. group the votes by option
    const groupedVotes = groupVotesByOption(votes)
    const votesForOption = groupedVotes[questionId]

    if (votesForOption.length === 0) {
        throw new Error(`No votes found for option ${questionId}`)
    }

    // 4. get the index of the vote to cancel
    const index = votesForOption.indexOf(jsEncryptedVoteToCancel.toHex())

    if (index === -1) {
        throw new Error(`Vote ${jsEncryptedVoteToCancel} not found for option ${questionId}`)
    }

    // 5. create the merkle trees for each option (in case of multi option elections)
    const merkleTree = new LeanIMT(
      hashLeanIMT as unknown as LeanIMTHashFunction,
      votesForOption.map((vote) => hashEncryptedVote(vote))
    )

    // 6. Generate the merkle tree inclusion proof 
    const proof = merkleTree.generateProof(index)

    // 7. Fill out the circuit inputs
    const { index: proofIndex, root } = proof

    const siblingsLength = proof.siblings.length
    for (let i = 0; i < TREE_DEPTH; i += 1) {
      if (i >= siblingsLength) {
        proof.siblings[i] = 0n
      }
    }

    const inputs: ICircuitInputs = {
        electionPublicKey: chunkedElectionPubKey,
        adminSecretSalt: BigInt(adminSecretSalt),
        voteSecretRandomizer: bigintTo255Bits(BigInt(voteSecretRandomizer)),
        rootHashOfAllEncryptedVotes: BigInt(root),
        actualTreeDepth: BigInt(merkleTree.depth),
        encodedVoteToSecretlyCancel: encodedVoteToCancelChunked,
        merklePathOfCancelledVote: proof.siblings.map(BigInt),
        merklePathIndex: BigInt(proofIndex),
        jsEncryptedVoteToCancel: jsEncryptedVoteToCancelChunked,
    }

    // 8. Generate the snark proof
    const snarkProof = await groth16.fullProve(inputs as unknown as CircuitSignals, wasmPath, zKeyPath)

    console.log("Proof generated successfully")
    console.log({snarkProof})

    await cleanThreads()
}

main().catch(console.error)
