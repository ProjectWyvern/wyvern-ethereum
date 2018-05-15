/*

  Delegated self-upgrading shareholders association.

  Originally based on the Shareholder Association example from https://ethereum.org/dao.
  
  Modified to support vote delegation, self-ownership, and board members - modifications in detail:

    Delegation

      Motivation
      
        A basic shareholder association only allows shareholders to vote directly. This poses a usability limitation and an attack risk. Small shareholders are unlikely to invest time evaluating and voting on proposals,
        especially if proposals are frequent, so an active shareholder association with many small shareholders would need a low quorum threshold - thus rendering it easier for a malicious party to buy enough shares to
        pass a proposal in their exclusive interest (for example, that sends all the DAO's assets to their account) before enough shareholders are paying attention. Vote delegation - allowing shareholders to choose someone
        else to vote in their stead - solves this problem, as small shareholders need only choose a trusted delegate once (and check back occaisionally to make sure they still approve of the delegate's votes).

      Implementation 

        Any shareholder in the DAO (which is anyone who holds the associated token) can voluntarily delegate any portion of their voting stake to another address.
        They do so by sending the tokens which they wish to delegate to the DAO, which locks them until the user undelegates their tokens, at which point the DAO returns the tokens to the user.
        While locked, these tokens count as extra votes for the address to whom the user delegated their tokens.
        Tokens can be unlocked at any time, and once unlocked no longer count as delegated votes.
        Notably, this allows delegating shareholders to *withdraw* their support for a proposal under consideration before the execution deadline even if their delegate had originally voted in favor of the proposal.

      Notes

        Delegated votes are counted when a proposal is finalized and executed (or not) - there's no way to move tokens around to create more votes than tokens and/or cause any tokens to count twice.
        The DAO is prevented from spending these locked tokens in the executeProposal function, so users who lock tokens are guaranteed the ability to withdraw them whenever they choose (no reserve banking).

    Self-Ownership

      Only the DAO itself can change its own voting rules (not an owning address). 
      This poses the small risk that a large amount of shareholders not voting could cause the DAO never to be able to reach quorum (and thus change the required quorum),
        but given the strong incentives for shareholders to avoid that (since a dysfunctional DAO would render their shares less valuable) and the expected liquidity of share tokens,
        this seems unlikely.

    Board Members

      A modicum of shares is required to create proposals to prevent proposal spam by shareholders only holding a tiny amount of tokens.
      This threshold can be adjusted by the DAO over time, so it shouldn't pose a capital barrier to proposal ideas.

*/

pragma solidity 0.4.23;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "../common/TokenRecipient.sol";
import "../common/TokenLocker.sol";

/**
 * @title DelegatedShareholderAssociation
 * @author Project Wyvern Developers
 */
contract DelegatedShareholderAssociation is TokenRecipient {

    uint public minimumQuorum;
    uint public debatingPeriodInMinutes;
    Proposal[] public proposals;
    uint public numProposals;
    ERC20 public sharesTokenAddress;

    /* Delegate addresses by delegator. */
    mapping (address => address) public delegatesByDelegator;

    /* Locked tokens by delegator. */
    mapping (address => uint) public lockedDelegatingTokens;

    /* Delegated votes by delegate. */
    mapping (address => uint) public delegatedAmountsByDelegate;
    
    /* Tokens currently locked by vote delegation. */
    uint public totalLockedTokens;

    /* Threshold for the ability to create proposals. */
    uint public requiredSharesToBeBoardMember;

    /* Token Locker contract. */
    TokenLocker public tokenLocker;

    /* Events for all state changes. */

    event ProposalAdded(uint proposalID, address recipient, uint amount, bytes metadataHash);
    event Voted(uint proposalID, bool position, address voter);
    event ProposalTallied(uint proposalID, uint yea, uint nay, uint quorum, bool active);
    event ChangeOfRules(uint newMinimumQuorum, uint newDebatingPeriodInMinutes, address newSharesTokenAddress);
    event TokensDelegated(address indexed delegator, uint numberOfTokens, address indexed delegate);
    event TokensUndelegated(address indexed delegator, uint numberOfTokens, address indexed delegate);

    struct Proposal {
        address recipient;
        uint amount;
        bytes metadataHash;
        uint timeCreated;
        uint votingDeadline;
        bool finalized;
        bool proposalPassed;
        uint numberOfVotes;
        bytes32 proposalHash;
        Vote[] votes;
        mapping (address => bool) voted;
    }

    struct Vote {
        bool inSupport;
        address voter;
    }

    /* Only shareholders can execute a function with this modifier. */
    modifier onlyShareholders {
        require(ERC20(sharesTokenAddress).balanceOf(msg.sender) > 0);
        _;
    }

    /* Only the DAO itself (via an approved proposal) can execute a function with this modifier. */
    modifier onlySelf {
        require(msg.sender == address(this));
        _;
    }

    /* Any account except the DAO itself can execute a function with this modifier. */
    modifier notSelf {
        require(msg.sender != address(this));
        _;
    }

    /* Only a shareholder who has *not* delegated his vote can execute a function with this modifier. */
    modifier onlyUndelegated {
        require(delegatesByDelegator[msg.sender] == address(0));
        _;
    }

    /* Only boardmembers (shareholders above a certain threshold) can execute a function with this modifier. */
    modifier onlyBoardMembers {
        require(ERC20(sharesTokenAddress).balanceOf(msg.sender) >= requiredSharesToBeBoardMember);
        _;
    }

    /* Only a shareholder who has delegated his vote can execute a function with this modifier. */
    modifier onlyDelegated {
        require(delegatesByDelegator[msg.sender] != address(0));
        _;
    }

    /**
      * Delegate an amount of tokens
      * 
      * @notice Set the delegate address for a specified number of tokens belonging to the sending address, locking the tokens.
      * @dev An address holding tokens (shares) may only delegate some portion of their vote to one delegate at any one time
      * @param tokensToLock number of tokens to be locked (sending address must have at least this many tokens)
      * @param delegate the address to which votes equal to the number of tokens locked will be delegated
      */
    function setDelegateAndLockTokens(uint tokensToLock, address delegate)
        public
        onlyShareholders
        onlyUndelegated
        notSelf
    {
        lockedDelegatingTokens[msg.sender] = tokensToLock;
        delegatedAmountsByDelegate[delegate] = SafeMath.add(delegatedAmountsByDelegate[delegate], tokensToLock);
        totalLockedTokens = SafeMath.add(totalLockedTokens, tokensToLock);
        delegatesByDelegator[msg.sender] = delegate;
        require(sharesTokenAddress.transferFrom(msg.sender, tokenLocker, tokensToLock));
        require(sharesTokenAddress.balanceOf(tokenLocker) == totalLockedTokens);
        emit TokensDelegated(msg.sender, tokensToLock, delegate);
    }

    /** 
     * Undelegate all delegated tokens
     * 
     * @notice Clear the delegate address for all tokens delegated by the sending address, unlocking the locked tokens.
     * @dev Can only be called by a sending address currently delegating tokens, will transfer all locked tokens back to the sender
     * @return The number of tokens previously locked, now released
     */
    function clearDelegateAndUnlockTokens()
        public
        onlyDelegated
        notSelf
        returns (uint lockedTokens)
    {
        address delegate = delegatesByDelegator[msg.sender];
        lockedTokens = lockedDelegatingTokens[msg.sender];
        lockedDelegatingTokens[msg.sender] = 0;
        delegatedAmountsByDelegate[delegate] = SafeMath.sub(delegatedAmountsByDelegate[delegate], lockedTokens);
        totalLockedTokens = SafeMath.sub(totalLockedTokens, lockedTokens);
        delete delegatesByDelegator[msg.sender];
        require(tokenLocker.transfer(msg.sender, lockedTokens));
        require(sharesTokenAddress.balanceOf(tokenLocker) == totalLockedTokens);
        emit TokensUndelegated(msg.sender, lockedTokens, delegate);
        return lockedTokens;
    }

    /**
     * Change voting rules
     *
     * Make so that proposals need tobe discussed for at least `minutesForDebate/60` hours
     * and all voters combined must own more than `minimumSharesToPassAVote` shares of token `sharesAddress` to be executed
     * and a shareholder needs `sharesToBeBoardMember` shares to create a transaction proposal
     *
     * @param minimumSharesToPassAVote proposal can vote only if the sum of shares held by all voters exceed this number
     * @param minutesForDebate the minimum amount of delay between when a proposal is made and when it can be executed
     * @param sharesToBeBoardMember the minimum number of shares required to create proposals
     */
    function changeVotingRules(uint minimumSharesToPassAVote, uint minutesForDebate, uint sharesToBeBoardMember)
        public
        onlySelf
    {
        if (minimumSharesToPassAVote == 0 ) {
            minimumSharesToPassAVote = 1;
        }
        minimumQuorum = minimumSharesToPassAVote;
        debatingPeriodInMinutes = minutesForDebate;
        requiredSharesToBeBoardMember = sharesToBeBoardMember;
        emit ChangeOfRules(minimumQuorum, debatingPeriodInMinutes, sharesTokenAddress);
    }

    /**
     * Add Proposal
     *
     * Propose to send `weiAmount / 1e18` ether to `beneficiary` for `jobMetadataHash`. `transactionBytecode ? Contains : Does not contain` code.
     *
     * @dev Submit proposal for the DAO to execute a particular transaction. Submitter should check that the `beneficiary` account exists, unless the intent is to burn Ether.
     * @param beneficiary who to send the ether to
     * @param weiAmount amount of ether to send, in wei
     * @param jobMetadataHash Hash of job metadata (IPFS)
     * @param transactionBytecode bytecode of transaction
     */
    function newProposal(
        address beneficiary,
        uint weiAmount,
        bytes jobMetadataHash,
        bytes transactionBytecode
    )
        public
        onlyBoardMembers
        notSelf
        returns (uint proposalID)
    {
        /* Proposals cannot be directed to the token locking contract. */
        require(beneficiary != address(tokenLocker));
        proposalID = proposals.length++;
        Proposal storage p = proposals[proposalID];
        p.recipient = beneficiary;
        p.amount = weiAmount;
        p.metadataHash = jobMetadataHash;
        p.proposalHash = keccak256(beneficiary, weiAmount, transactionBytecode);
        p.timeCreated = now;
        p.votingDeadline = now + debatingPeriodInMinutes * 1 minutes;
        p.finalized = false;
        p.proposalPassed = false;
        p.numberOfVotes = 0;
        emit ProposalAdded(proposalID, beneficiary, weiAmount, jobMetadataHash);
        numProposals = proposalID+1;
        return proposalID;
    }

    /**
     * Check if a proposal code matches
     *
     * @param proposalNumber ID number of the proposal to query
     * @param beneficiary who to send the ether to
     * @param weiAmount amount of ether to send
     * @param transactionBytecode bytecode of transaction
     */
    function checkProposalCode(
        uint proposalNumber,
        address beneficiary,
        uint weiAmount,
        bytes transactionBytecode
    )
        public
        view
        returns (bool codeChecksOut)
    {
        Proposal storage p = proposals[proposalNumber];
        return p.proposalHash == keccak256(beneficiary, weiAmount, transactionBytecode);
    }

    /**
     * Log a vote for a proposal
     *
     * Vote `supportsProposal? in support of : against` proposal #`proposalNumber`
     *
     * @dev Vote in favor or against an existing proposal. Voter should check that the proposal destination account exists, unless the intent is to burn Ether.
     * @param proposalNumber number of proposal
     * @param supportsProposal either in favor or against it
     */
    function vote(
        uint proposalNumber,
        bool supportsProposal
    )
        public
        onlyShareholders
        notSelf
        returns (uint voteID)
    {
        Proposal storage p = proposals[proposalNumber];
        require(p.voted[msg.sender] != true);
        voteID = p.votes.length++;
        p.votes[voteID] = Vote({inSupport: supportsProposal, voter: msg.sender});
        p.voted[msg.sender] = true;
        p.numberOfVotes = voteID + 1;
        emit Voted(proposalNumber, supportsProposal, msg.sender);
        return voteID;
    }

    /**
     * Return whether a particular shareholder has voted on a particular proposal (convenience function)
     * @param proposalNumber proposal number
     * @param shareholder address to query
     * @return whether or not the specified address has cast a vote on the specified proposal
     */
    function hasVoted(uint proposalNumber, address shareholder) public view returns (bool) {
        Proposal storage p = proposals[proposalNumber];
        return p.voted[shareholder];
    }

    /**
     * Count the votes, including delegated votes, in support of, against, and in total for a particular proposal
     * @param proposalNumber proposal number
     * @return yea votes, nay votes, quorum (total votes)
     */
    function countVotes(uint proposalNumber) public view returns (uint yea, uint nay, uint quorum) {
        Proposal storage p = proposals[proposalNumber];
        yea = 0;
        nay = 0;
        quorum = 0;
        for (uint i = 0; i < p.votes.length; ++i) {
            Vote storage v = p.votes[i];
            uint voteWeight = SafeMath.add(sharesTokenAddress.balanceOf(v.voter), delegatedAmountsByDelegate[v.voter]);
            quorum = SafeMath.add(quorum, voteWeight);
            if (v.inSupport) {
                yea = SafeMath.add(yea, voteWeight);
            } else {
                nay = SafeMath.add(nay, voteWeight);
            }
        }
    }

    /**
     * Finish vote
     *
     * Count the votes proposal #`proposalNumber` and execute it if approved
     *
     * @param proposalNumber proposal number
     * @param transactionBytecode optional: if the transaction contained a bytecode, you need to send it
     */
    function executeProposal(uint proposalNumber, bytes transactionBytecode)
        public
        notSelf
    {
        Proposal storage p = proposals[proposalNumber];

        /* If at or past deadline, not already finalized, and code is correct, keep going. */
        require((now >= p.votingDeadline) && !p.finalized && p.proposalHash == keccak256(p.recipient, p.amount, transactionBytecode));

        /* Count the votes. */
        uint yea;
        uint nay;
        uint quorum;
        ( yea, nay, quorum ) = countVotes(proposalNumber);
        /* Honestly, Solidity... https://github.com/ethereum/solidity/issues/3520 */

        /* Assert that a minimum quorum has been reached. */
        require(quorum >= minimumQuorum);
        
        /* Mark proposal as finalized. */   
        p.finalized = true;

        if (yea > nay) {
            /* Mark proposal as passed. */
            p.proposalPassed = true;

            /* Execute the function. */
            require(p.recipient.call.value(p.amount)(transactionBytecode));

        } else {
            /* Proposal failed. */
            p.proposalPassed = false;
        }

        /* Log event. */
        emit ProposalTallied(proposalNumber, yea, nay, quorum, p.proposalPassed);
    }
}
