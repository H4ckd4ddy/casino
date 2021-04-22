// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

contract casino {
    
    // We use finney (ST)
    uint256 public money_value = 1e15;
    
    
    /*####################*\
      #      Utils       #
    \*####################*/
    function random() private view returns(uint){
        return uint8(uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp))));
    }
    
    /*####################*\
      #    Take bets     #
    \*####################*/
    bool public bets_open = true;
    uint public result;
    struct Bet {
        bool choice;
        uint256 amount;
        bool ready;
        uint256 this_result;
        uint256 players_count;
        uint256 total_false;
        uint256 total_true;
        uint256 win;
    }
    address[] private players;
    uint256 ready_count = 0;
    mapping(address => Bet) private bets;
    mapping(address => Bet) private last_bets;
    uint256 total_bets_false = 0;
    uint256 total_bets_true = 0;
    
    function get_last_bet(address _address) public view returns (bool choice, uint256 amount, uint256 this_result, uint256 win, uint256 players_count, uint256 total_false, uint256 total_true){
        Bet memory last_bet = last_bets[_address];
        return (last_bet.choice, last_bet.amount, last_bet.this_result, last_bet.win, last_bet.players_count, last_bet.total_false, last_bet.total_true);
    }
    
    function get_bet(address _address) public view returns (bool choice, uint256 amount, bool ready, uint256 players_count, uint256 players_ready_count, uint256 total_false, uint256 total_true){
        Bet memory bet = bets[_address];
        return (bet.choice, bet.amount, bet.ready, players.length, ready_count, total_bets_false, total_bets_true);
    }
    
    function get_players_length() public view returns (uint256){
        return players.length;
    }
    
    function place_bet(uint _amount, bool _choice) public returns (bool){
        require(bets_open);
        require(_amount > 0);
        require(_amount <= accounts[msg.sender]);
        require(bets[msg.sender].amount == 0);
        accounts[msg.sender] -= _amount;
        bets[msg.sender] = Bet({
            choice: _choice,
            amount: _amount,
            ready: false,
            this_result: 0,
            players_count: 0,
            total_false: 0,
            total_true: 0,
            win: 0
        });
        players.push(msg.sender);
        if(bets[msg.sender].choice){
            total_bets_true += bets[msg.sender].amount;
        }else{
            total_bets_false += bets[msg.sender].amount;
        }
        return true;
    }
    function set_ready() public returns (bool){
        require(bets[msg.sender].amount > 0);
        require(!bets[msg.sender].ready);
        bets[msg.sender].ready = true;
        ready_count += 1;
        bool everyone_ready = true;
        for(uint player = 0;player < players.length;player++){
            if(!bets[players[player]].ready){
                everyone_ready = false;
                break;
            }
        }
        if(everyone_ready){
            fire();
        }
        return true;
    }
    function fire() private{
        bets_open = false;
        result = random();
        bool bool_result = (result >= 128);
        for(uint player = 0;player < players.length;player++){
            bets[players[player]].this_result = result;
            bets[players[player]].players_count = players.length;
            bets[players[player]].total_false = total_bets_false;
            bets[players[player]].total_true = total_bets_true;
            if(bets[players[player]].choice == bool_result){
                uint256 other_side = 0;
                uint256 this_side = 0;
                if(bool_result){
                    other_side = total_bets_false;
                    this_side = total_bets_true;
                }else{
                    other_side = total_bets_true;
                    this_side = total_bets_false;
                }
                bets[players[player]].win = ((bets[players[player]].amount/this_side)*other_side)+bets[players[player]].amount;
                accounts[players[player]] += bets[players[player]].win;
            }
            last_bets[players[player]] = bets[players[player]];
            delete bets[players[player]];
        }
        delete players;
        result = 0;
        total_bets_true = 0;
        total_bets_false = 0;
        ready_count = 0;
        bets_open = true;
    }
    
    
    
    /*####################*\
      # Owner management #
    \*####################*/
    address private owner;
    
    event owner_set(address indexed old_owner, address indexed new_owner);
    
    modifier is_owner() {
        require(msg.sender == owner, "Only owner can do that");
        _;
    }
    constructor() {
        owner = msg.sender;
        emit owner_set(address(0), owner);
    }
    function change_owner(address new_owner) public is_owner {
        emit owner_set(owner, new_owner);
        owner = new_owner;
    }
    function get_owner() external view returns (address) {
        return owner;
    }
    
    /*####################*\
      #  Tax management  #
    \*####################*/
    uint8 public current_tax = 0;
    
    event tax_set(uint8 indexed old_tax, uint8 indexed new_tax);
    
    function change_tax(uint8 new_tax) public is_owner {
        emit tax_set(current_tax, new_tax);
        current_tax = new_tax;
    }
    
    /*#######################*\
      # Accounts management #
    \*#######################*/
    address[] private accounts_list;
    mapping(address => uint) private accounts;
    
    receive() external payable {
        require((msg.value / money_value) > 0);
        accounts[msg.sender] += (msg.value / money_value) - current_tax;
        accounts[owner] += current_tax;
        if(accounts[msg.sender] == 0){
            accounts_list.push(msg.sender);
        }
    }
    function get_balance(address _address) public view returns (uint){
        return accounts[_address];
    }
    function withdraw(uint256 _amount) public returns(bool) {
        require(_amount <= accounts[msg.sender]);
        payable(msg.sender).transfer(_amount * money_value);
        accounts[msg.sender] -= _amount;
        return true;
    }
    
    function withdraw_all() public is_owner {
        for(uint account = 0;account < accounts_list.length;account++){
            if(accounts[accounts_list[account]] > 0){
                payable(accounts_list[account]).transfer(accounts[accounts_list[account]] * money_value);
            }
        }
    }
    
    function destroy_casino() public is_owner {
        withdraw_all();
        selfdestruct(payable(owner));
    }
    
}