// SPDX-License-Identifier: MIT LICENSE
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


//https://zakariae.de 
// zakariae portfolio Project

contract zakariae is IERC721Receiver, ReentrancyGuard, Ownable {

    IERC721 public twicryptCollection ;
    IERC20 public twicryptToken  ;
    
    //stats
    uint256 totalMined = 0; // total mined since launch
    uint32 totalMiners = 0; // total since launch miners 
    //math
    uint256 nftMinngRate = 80 ; // nft rate impact on mining
    uint256 bankMiningRate = 8; // mining rate for bank
    uint256 MAX_MINING_TIME = 30 seconds; // mining session mength
    uint256 boostDuration = 12 hours; // boost length
    uint256 claimWait = 24 hours; // time between claiming to wallet
    uint256 COOLDOWN_TIME = 10 seconds; // time between sessions
    //requirements
    uint256 minFundsTowithdraw = 100*10**18; // min funds in bank to withdraw
    bool  claimEnabled = false;
    uint256 minClaimTokenHolding = 100**18 ; // min token holdings to claim rewards to wallet
    uint8 minClaimNftHolding = 1 ; // min nft holdings to claim rewards to wallet
    uint8 minNftForMining = 1; // minHoldings of nfts for mining start
    //fees
    uint256 boostFees = 347000000000000;
    // 347000000000000; // fees/price to boost
    uint8 ClaimfeesPercent = 10; // fees percent to deduct from bank funds after claim
    //claim conditions
    uint256 maxClaimAmount = 1000*10**18;



 struct stats {
    uint256 total_mined; 
    uint32 total_miners; 
    uint256 nft_minng_rate; 
    uint256 bank_mining_rate; 
    uint256 max_mining_time;
    uint256 boost_duration;
    uint256 claim_wait;
    uint256 couldown_time;
    uint256 min_funds_to_withdraw;
    bool  claim_enabled ;
    uint256 min_claim_token_holding;
    uint8 min_claim_nft_holding;
    uint8 min_nft_for_mining; 
    uint256 boost_fees;
    uint8 claim_fees_percent;
    uint256 maxclaim_amount;
 }
    struct PlayerSession {
        uint256 totalUsedNfts;
        uint16 totalSessions;
        uint256 miningPower;
        uint256 lastMiningSession;
        uint256 miningStartTime;
        uint256 miningEndTime;
        uint256 earnedRewards;
        uint8 giftCount;
        uint256 lastClaim;
    }

mapping(address => PlayerSession) public sessionData; //ui uses it

struct Bank{
    uint8 level;
    uint256 capacity;
    string imageUrl;
    uint256 funds;
}

mapping(address=>Bank)  Banks;

struct banksUpgrades {
    uint8 level;
    uint256 capacity;
    uint256 price;
    string imageUrl;
}

mapping(uint256=>banksUpgrades) upgrades;

struct stakedNft {
uint256 tokenId;
string imageUrl;
}

mapping(address=>uint256)  nftBalances; // store balance for each user
mapping (uint256=>uint256)  nftIndexes; // array tokenid => index
mapping(address => stakedNft[]  ) stakedNfts; //array of staked nfts

mapping(address=>uint256) boostTime ; // boost time + duration
mapping(uint256=>bool  )  isOld; // token id point to staking status

struct allData {
    PlayerSession userData;
    Bank bankData ;
    stakedNft[] staked;
    uint256 nftBalance;
    uint256 boostEndTime;
}

function claimGift() external onlyMiner() {
  uint256 index = sessionData[_msgSender()].giftCount;
require(Banks[_msgSender()].funds >=upgrades[index].capacity , "not eligible");
uint256 giftAmount = (upgrades[index].capacity/10);
require(Banks[_msgSender()].funds+giftAmount<= Banks[_msgSender()].capacity,"cannot deposit funds upgrade your bank and claim again!");
    Banks[_msgSender()].funds+=giftAmount;
    sessionData[_msgSender()].earnedRewards+=giftAmount;
    sessionData[_msgSender()].giftCount+=1;
    totalMined+=giftAmount;
}
    constructor(IERC721 _twicryptNftAddress, IERC20 _twicryptToken) {
        twicryptCollection = _twicryptNftAddress;
        twicryptToken = _twicryptToken;
      
    }

//-----------------------------erc721 receiver-----------------------------------//
  function onERC721Received(
        address,
        address from,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        require(from == address(0x0), "Cannot send nfts to Vault directly");
        return IERC721Receiver.onERC721Received.selector;
    }
//-----------------------------Modifiers-----------------------------------//

    modifier ClaimCondition() {
        require(twicryptCollection.balanceOf(_msgSender()) >= minClaimNftHolding,"you do not own twicrypt nft");
        require(IERC20(twicryptToken).balanceOf(_msgSender())>= minClaimTokenHolding,"you need to hold certain amount of tokens");
        _;}

    modifier OnlyNftHolder (){
        uint256 b = twicryptCollection.balanceOf(_msgSender());
               require(b>=minNftForMining,"you do not own twicrypt nft");
        _;}

modifier miningConditions {
     require(sessionData[_msgSender()].miningEndTime < block.timestamp,"Mining session has not been completed yet !");
        require(sessionData[_msgSender()].miningStartTime <= block.timestamp,"mining session can't start now you come back later ");
                require(nftBalances[_msgSender()]>0, "you have no active miners");
                     require(Banks[_msgSender()].level>0, "claim your free bank");

_;
}

modifier onlyMiner (){
    require(nftBalances[_msgSender()]>0 , "you need to have active miners");
    _;
}
 
//-----------------------------payment-----------------------------------//
    receive() external payable {}
//-----------------------------events-----------------------------------//



    event sessionStarted(address indexed user, uint256 indexed totalNfts);
    event userClaimed(address indexed user, uint256 indexed amount);
    event bankUpgraded(address indexed user, uint256 indexed level ,uint256 indexed capacity);
    event addedToBank(address indexed user , uint256 amount);
    
//-----------------------------setters-----------------------------------//

    // uint256 claimWait = 24 hours; // time between claiming to wallet

    function setRewardToken(IERC20 _token) external onlyOwner() {twicryptToken = _token;}
    function setCollection(IERC721 _nft) external onlyOwner() {twicryptCollection = _nft;}
    function set_Boost_Data(uint256 _duration , uint256 _fees) external onlyOwner() {boostDuration = _duration; boostFees=_fees;}
    function enable_Claim_Rewards(bool _enable, uint256 _claimWait) external onlyOwner() {claimEnabled = _enable; claimWait = _claimWait;}
    function setNftMiningRate(uint256 _rate) external onlyOwner() {nftMinngRate = _rate;}
    function setBankMiningRate(uint256 _rate) external onlyOwner() {bankMiningRate = _rate;}

    function set_mining_settings (uint256 _cooldownTime,uint256 _miningDuration) external onlyOwner() {
            COOLDOWN_TIME = _cooldownTime;
            MAX_MINING_TIME = _miningDuration;
    }
    function set_claim_conditions (uint256 _maxClaimAmount,uint256 _minFundsTowithdraw,uint8 _claimFees, uint256 _minClaimTokenHoldings,uint8 _minClaimNftHoldings) external onlyOwner() {
            maxClaimAmount = _maxClaimAmount;
            minFundsTowithdraw = _minFundsTowithdraw;
            ClaimfeesPercent = _claimFees;
            minClaimNftHolding = _minClaimNftHoldings;
            minClaimTokenHolding = _minClaimTokenHoldings;
    }
    
    function set_Mining_holdings_conditions (uint8 _minNftForMining)external onlyOwner() {
            minNftForMining = _minNftForMining;
    }

function setNewUpgrade (uint8 _level , uint256 _capacity,string calldata _imageUrl ,uint256 _price, uint256 _index) external onlyOwner() {
    banksUpgrades memory newupgrade = banksUpgrades(
        _level,
        _capacity,
        _price,
        _imageUrl
    );
    upgrades[_index] = newupgrade;
}

function boostEnded () internal view returns (bool) {
  bool isEnded =  boostTime[msg.sender] - block.timestamp >= MAX_MINING_TIME ? false : true ;
return isEnded ;
}

function setBoostForUser(address _addrs, uint256 _newTime) external onlyOwner() {
    boostTime[_addrs] = block.timestamp+_newTime;

}

function rechargeBoost()external onlyMiner()  {
    require(boostTime[_msgSender()] > 0 , "you have not claimed your bank");
     uint256 price = calculateBoostPrice();

    require(Banks[_msgSender()].funds >= price , " insufficient funds" );
     Banks[_msgSender()].funds -= price;
     boostTime[_msgSender()] = block.timestamp+boostDuration;
}

//-----------------------------Getters-----------------------------------//

function getAllBanks() external view returns(banksUpgrades[] memory){
    banksUpgrades[] memory data = new  banksUpgrades[](10);
            for (uint i =1 ; i<10 ; i++) {
           data[i] =(upgrades[i]) ;
            }
           return data;
}

 function getAllData (address _addr) external view returns (allData memory) {
     stakedNft[] storage staked = stakedNfts[_addr];
    allData memory data = allData(sessionData[_addr],Banks[_addr],staked,nftBalances[_addr],boostTime[_addr]);
return data;
 }

 function getStats ()external view returns( stats memory){
    stats memory newStats = stats (
     totalMined,
     totalMiners,
     nftMinngRate,
     bankMiningRate,
     MAX_MINING_TIME ,
     boostDuration,
     claimWait,
     COOLDOWN_TIME,
     minFundsTowithdraw,
     claimEnabled,
     minClaimTokenHolding,
     minClaimNftHolding,
     minNftForMining,
     boostFees,
     ClaimfeesPercent,
     maxClaimAmount
    );
return newStats;
}

function getStacked (address _user) public view returns (stakedNft[] memory) {
   return stakedNfts[_user];
}

//-----------------------------Bank-----------------------------------//

function claimBank () external  OnlyNftHolder() {
    require( Banks[_msgSender()].capacity == 0, "free bank already claimed" );
    uint8 level = upgrades[1].level;
    string memory imgurl = upgrades[1].imageUrl;
    uint256 capacity = upgrades[1].capacity;
    Banks[_msgSender()] = Bank(
    level,
    capacity,
    imgurl,
    0);
    uint256 power = calculatePower();
    boostTime[_msgSender()] = block.timestamp+boostDuration;
    sessionData[_msgSender()].miningPower =power;
    sessionData[_msgSender()].giftCount = 1;
    totalMiners+=1;
}

function upgrade () external payable {
    uint256 currentLevel = Banks[_msgSender()].level; //1
    uint8 newLevel = upgrades[currentLevel+1].level; //2
    require(Banks[_msgSender()].level > 0 , "you need to claim your free bank first in order to upgrade it! ");
    require(upgrades[newLevel].level != currentLevel);
    require(upgrades[newLevel].level != 0  , "maximum level reached !"); // 
    require(msg.value == upgrades[currentLevel+1].price);
     Banks[_msgSender()].level = newLevel;
    Banks[_msgSender()].capacity = upgrades[currentLevel+1].capacity;
    Banks[_msgSender()].imageUrl = upgrades[currentLevel+1].imageUrl;
        uint256 power = calculatePower();
        sessionData[_msgSender()].miningPower =power;
    emit bankUpgraded (_msgSender() , currentLevel,Banks[_msgSender()].capacity  );
}

//-----------------------------Math-----------------------------------//

function calculateCapacity (address _user)internal view returns (uint256) {
return  Banks[_user].capacity  - Banks[_user].funds ;
}

function calculatePower ()internal view returns (uint256){
   uint256 userNft = nftBalances[_msgSender()];
   uint256 level = Banks[_msgSender()].level;
   uint256 power = (userNft*nftMinngRate)+(level*bankMiningRate)/2;
   uint256 totalPower = power*10**14;
   return totalPower;
}

  function calculateSessioRewards(address _user)internal view returns (uint256){
        if (sessionData[_user].lastMiningSession == 0 || sessionData[_user].miningEndTime == 0) {
            return 0;
        }
        uint256 userPower = sessionData[_msgSender()].miningPower;
        uint256 timeElapsed = block.timestamp - sessionData[_user].lastMiningSession;
        uint256 rewards = timeElapsed * userPower ;
        if (rewards > MAX_MINING_TIME * userPower ) {
            rewards = MAX_MINING_TIME * userPower;
        }
        return rewards;
    }

function calculateBoostPrice () internal view returns (uint256){
        uint256 nftBalance = nftBalances[_msgSender()];
require(nftBalance>0 , "you have no nfts cannot calculate fees");
 if (block.timestamp >= boostTime[_msgSender()]){
      return ((boostFees*boostDuration)*nftBalance);
    }else {
        uint256 diffrence =  boostTime[_msgSender()] - block.timestamp  ; 
        uint256 sub = boostDuration - diffrence;
        uint256 total = (sub * boostFees);
        return (total * nftBalance);
    }
}

// ["1","2","3","4","5","6","7","8","9","10","11","12","13","14","15"]
//["","","","","","","","","","","","","","",""]

//-------------------------- session Mining --------------------------//

    function addToBank () internal {
        uint256 rewards = calculateSessioRewards(_msgSender());
        uint256 capacity = calculateCapacity(_msgSender());
        if(capacity >= rewards){
                sessionData[_msgSender()].earnedRewards +=rewards;
                Banks[_msgSender()].funds+=rewards;
                totalMined+=rewards;
                        }else {
                                sessionData[_msgSender()].earnedRewards +=capacity;
                                Banks[_msgSender()].funds+=capacity;
                                totalMined+=capacity;
                        }
        emit addedToBank(_msgSender(),rewards);
    }

function stake (uint8 _tokenId ,string calldata _imageUrl) external nonReentrant  {
            require(twicryptCollection.ownerOf(_tokenId) == _msgSender(),"You do not own this Nft");
        stakedNft memory newNft = stakedNft(
            _tokenId,
            _imageUrl
        );
        uint256 length = stakedNfts[_msgSender()].length;
        nftIndexes[_tokenId]=length;
        stakedNfts[_msgSender()].push(newNft);
        twicryptCollection.transferFrom(_msgSender(), address(this), _tokenId);
        nftBalances[_msgSender()]+=1;
}

function stakeMultiple (uint8[] calldata _tokenId ,string[] calldata _imageUrl) external nonReentrant {
 address sender = _msgSender(); 
    require(Banks[sender].capacity >0 ,"claim free bank first ");
    for (uint8 i = 0 ; i< _tokenId.length;i++){
                 stakedNft memory newNft = stakedNft(
                _tokenId[i],
                _imageUrl[i]
            );
            require(
            twicryptCollection.ownerOf(_tokenId[i]) == _msgSender(),
            "You do not own this Nft"
        );
        isOld[_tokenId[i]]=true;
uint256 length = stakedNfts[sender].length;
nftIndexes[_tokenId[i]]=length;
stakedNfts[sender].push(newNft);
twicryptCollection.transferFrom(sender, address(this), _tokenId[i]);
    }
nftBalances[_msgSender()]+=_tokenId.length;

}

 function unstake(uint256 _tokenId) public onlyMiner() {
     require(sessionData[_msgSender()].miningEndTime<block.timestamp,"session has not been ended yet");
        uint256 index = nftIndexes[_tokenId];
        require(index < stakedNfts[_msgSender()].length, "NFT not found");
        // Swap the NFT to be unstaked with the last NFT in the array
        uint256 lastIndex = stakedNfts[_msgSender()].length - 1;
        stakedNft storage lastNft = stakedNfts[_msgSender()][lastIndex];
        stakedNfts[_msgSender()][index] = lastNft;
        // Update the index of the last NFT
        nftIndexes[lastNft.tokenId] = index;
        // Remove the last NFT from the array
        stakedNfts[_msgSender()].pop();
        // Remove the token ID from the index mapping
        delete nftIndexes[_tokenId];
        twicryptCollection.transferFrom(address(this), _msgSender(), _tokenId);
        nftBalances[_msgSender()]-=1;
    }

function unstakeMultiple (uint8[] calldata _tokenId ) external nonReentrant onlyMiner() {
 address sender = _msgSender();
    for (uint8 i = 0 ; i< _tokenId.length;i++){
           uint256 index = nftIndexes[_tokenId[i]];
        require(index < stakedNfts[sender].length, "NFT not found");
           uint256 lastIndex = stakedNfts[sender].length - 1;
        stakedNft storage lastNft = stakedNfts[sender][lastIndex];
        stakedNfts[sender][index] = lastNft;
        nftIndexes[lastNft.tokenId] = index;
        stakedNfts[sender].pop();         
        delete nftIndexes[_tokenId[i]];
            require(
            twicryptCollection.ownerOf(_tokenId[i]) == sender,
            "You do not own this Nft"
        );
        twicryptCollection.transferFrom(address(this), sender, _tokenId[i]);
        nftBalances[sender]-=1;
    }
}

    function startSession() external miningConditions{

        bool boostEnd = boostEnded();
        require(!boostEnd,"boost ended please recharge");
        if (sessionData[_msgSender()].totalSessions != 0){
            addToBank();
        }

        uint256 userNft = nftBalances[_msgSender()];
        uint256 power = calculatePower();
        uint16 sessionCount = sessionData[_msgSender()].totalSessions+=1;
        uint256 endTime = block.timestamp + MAX_MINING_TIME;
        uint256 nextSession = endTime+COOLDOWN_TIME;
        uint8 prevGiftCount = sessionData[_msgSender()].giftCount;
        uint256 prevRewards = sessionData[_msgSender()].earnedRewards;

        sessionData[_msgSender()] = PlayerSession(
            userNft,
            sessionCount,
            power,
            block.timestamp,
            nextSession,
            endTime ,
            prevRewards,
            prevGiftCount,
            0
            );
        emit sessionStarted(_msgSender(), 1);
    }

    modifier withdrawEarnings () {
  require( sessionData[_msgSender()].lastClaim + claimWait <= block.timestamp , "you can only claim once in 24hrs");
        require(claimEnabled == true, "you can claim after launch !");
        require(twicryptCollection.balanceOf(_msgSender()) > 0,"you need to hold at least 1 Nft to claim rewards");
        require(twicryptToken.balanceOf(_msgSender()) > minClaimTokenHolding,"you need to hold at least 1 token to claim rewards");
        require(Banks[_msgSender()].funds >= minFundsTowithdraw,"minimum to withdraw not reached");

        _;
    }

    function withdraw_earnings() external withdrawEarnings()  {
        Banks[_msgSender()].funds = Banks[_msgSender()].funds-maxClaimAmount;
        uint256 fees = (maxClaimAmount*ClaimfeesPercent)/100;
        uint256 amount =  maxClaimAmount - fees;
        sessionData[_msgSender()].lastClaim =block.timestamp; // 10
        twicryptToken.transfer(_msgSender(), amount);
        emit userClaimed(_msgSender(), amount);
    }

  function withdraw() public payable onlyOwner() {
    (bool os, ) = payable(owner()).call{value: address(this).balance}("");
    require(os);
  }

  function withdraw_token (address _token) public onlyOwner() {
      uint256 balance = IERC20(_token).balanceOf(address(this)) ;
      IERC20(_token).transfer(_msgSender(),balance);
  }
}