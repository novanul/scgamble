pragma solidity ^0.4.15;

contract Gamble {
    enum State {
        Bet,
        Reveal,
        Lottery,
        End
    }
    struct Bet {
        uint coin;
        bool beton;
        bytes32 srand;
        bytes32 blindedSrand;
    }
    
    address public dealer;
    address public winner;
    address[] players;
    uint public chip;
    uint public timespan;
    uint public stateTime;
    State public state;
    
    mapping(address => Bet) bets;
    
    event StateChange(string currentState);
    event PlayersJoin(uint currentPlayersCount);
    
    modifier condition(bool _condition) {
        require(_condition);
        _;
    }
    modifier stateTimeIn() {
        require(now - stateTime < timespan);
        _;
    }
    modifier stateTimeOut() {
        require(now - stateTime > timespan);
        _;
    }
    modifier stateTimeOutTwoTimes() {
        require(now - stateTime > 2 * timespan);
        _;
    }
    modifier stateCheck(State _state) {
        require(state == _state);
        _;
    }
    
    function Gamble(uint _chip, uint _timespan) public {
        dealer = msg.sender;
        chip = _chip;
        timespan = _timespan;
        stateTime = now;//HOLDON: manual time?
        state = State.Bet;
        StateChange("End");
    }
    
    function destroy() public
        stateCheck(State.End)
    {
        require(msg.sender == dealer);
        selfdestruct(dealer);
    }
    
    function sha3Local(bytes32 srand) constant public returns(bytes32 blindedSrand) {
        blindedSrand = keccak256(srand);
    }
    
    function join(bool beton, bytes32 blindedSrand) public payable
        stateCheck(State.Bet)
        stateTimeIn()
    {
        require(msg.value == chip);//TODO: divided without remainder
        players.push(msg.sender);
        bets[msg.sender] = Bet({
            coin: msg.value,
            beton: beton,
            srand: 0,
            blindedSrand: blindedSrand
        });
        PlayersJoin(players.length);
    }

    function stateToReveal() public 
        stateCheck(State.Bet)
    {
        if (now - stateTime < timespan) {
            require(msg.sender == dealer);
        }
        stateTime = now;
        state = State.Reveal;
        StateChange("Reveal");
    }

    function stateToEnd() public
        stateCheck(State.Bet)
        stateTimeOut()
    {
        require(msg.sender == dealer && players.length == 0);
        stateTime = now;
        state = State.End;
        StateChange("End");
    }
    
    function reveal(bytes32 srand) public
        stateCheck(State.Reveal)
        stateTimeIn()
    {
        require(bets[msg.sender].blindedSrand != 0);
        Bet storage bet = bets[msg.sender];//TODO: a unexist address
        require(keccak256(srand) == bet.blindedSrand);
        bet.srand = srand;
    }
    
    function lottery() public
        stateCheck(State.Reveal)
    {
        if (now - stateTime < timespan) {
            require(msg.sender == dealer && isRevealedAll());
        }
        bytes32 fate = getFate();
        winner = getWinner(fate);
        //announce fate
        stateTime = now;
        state = State.Lottery;
        StateChange("Lottery");
    }
    
    function getWinner(bytes32 fate) internal returns(address) {
        address curWinner = 0;
        uint32 diff = uint32(-1); //greatest
        for (uint i = 0; i < players.length; i++) {
            var curPlayer = bets[players[i]];
            if (curPlayer.srand != 0){
                uint32 tmpFate = uint32(fate);
                uint32 tmpSrand = uint32(curPlayer.srand);
                uint32 newDiff = tmpFate - tmpSrand;
                if (newDiff < diff) {
                    curWinner = players[i];
                    diff = newDiff;
                }
            }
        }
        return curWinner;
    }
    
    function getFate() internal returns(bytes32) {
        bytes32 fate = 0;
        for (uint i = 0; i < players.length; i++) {
            var curSrand = bets[players[i]].srand;
            if (curSrand != 0) {
                fate = keccak256(fate, curSrand);
            }
        }
        return fate;
    }
    
    function isRevealedAll() internal returns(bool result) {
        result = true;
        for (uint i = 0; i < players.length; i++){
            if (bets[players[i]].srand == 0) {
                result = false;
                break;
            }
        }
    }
    
    function retrieve() public 
        stateCheck(State.Lottery)
        //stateTimeIn()
    {
        if (winner != 0) {
            require(msg.sender == winner);
            winner.transfer(this.balance);
        }
        else {
            dealer.transfer(this.balance);//temp 
        }
        stateTime = now;
        state = State.End;
        StateChange("End");
    }
    
}
