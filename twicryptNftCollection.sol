// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts@4.4.2/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.4.2/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts@4.4.2/access/Ownable.sol";
 

contract Twicrypt is ERC721 , ERC721Enumerable, Ownable {
  using Strings for uint256;


address public royaltyReceiver ;
uint256 public royaltyFees = 5;
string public contractURI ; 

  string public baseURI;
  string public baseExtension = ".json";
  uint256 public cost = 0.15 ether;
  uint256 public maxSupply = 10000;
  uint256 public totalContributions ;
  // maxMintAmount per every transaction
  uint256 public maxMintAmount = 10;
  uint256 public nftPerAddressLimit = 50;
  bool public paused = false;
  uint256 refPercent = 20;


  constructor(
    string memory _name,
    string memory _symbol,
    string memory _initBaseURI
  ) ERC721(_name, _symbol) {
    setBaseURI(_initBaseURI);
  }

receive() external payable {}

  // internal
  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }






mapping(address=>uint256) contributions;
mapping(address=>address[]) referrals ; // length referrals[refferer].length = 50
mapping(address=>uint256) public balances ;
mapping(address=>bool) public partners;
mapping(address=>uint256) public partnersPercent;
mapping (address=>uint256) public userContributions;
mapping (address=>uint256)public totalWithdrawls;
mapping (address=>uint256)public referralsContributions;

struct stats {
  uint256 reffCount; //user
  uint256 totalReward; // user
  address[] referrals ; // user
  // bool isReferrer; // user
  // bool isPartner;// user
  uint256 percentage;// user
  // uint256  reffConditon; // user
  uint256 userContributions; // user
  uint256  nftBalance; // user
  uint256 refContributions; // user
  uint256 totalWithdrawls; // user
}
struct mintStats {
string  baseURI; // app
uint256  cost ; 
uint256  maxSupply ; // app
uint256  maxMintAmount; // app
uint256  nftPerAddressLimit;//app
uint256  totalContributions; //app
uint256 supply ; //app
bool  paused; // app
  
  }



////////////////////////////////////////////////////////////////////////////////////////////////////////////

struct nftReward {
  uint256 tokenId;
  uint256 reward;
  bool claimed ;
  uint256 claimedReward;
  bool hasReward;
  string metadata;
  string image;
  address claimer;
  uint256 claimedAt;
}

mapping(uint256=>nftReward) NftReward ;
nftReward[] winningNfts;//80 === 80  
nftReward[] claimedRewardsFromNfts;//0 1  2

struct NftRewardStats {
  bool userHaswon;
  nftReward [] myWiningNfts;

}


function getUserNftRewardStats (address _addr) external view returns (NftRewardStats memory) {
  NftRewardStats memory userRewardStats = NftRewardStats (
    hasWinningNft(_addr),
    checkMyNfts(_addr)
  ) ;
  return userRewardStats;
}
function getUiNftRewardStats () external view returns (nftReward[] memory , nftReward[] memory) {
  return (winningNfts , claimedRewardsFromNfts);
}

function delete_after_claim (uint256 _index) internal {
  uint256 _lastIndex = winningNfts.length -1 ;
 winningNfts[_index] = winningNfts[_lastIndex];
   winningNfts.pop();
}

function editWinning (uint256 _tId,uint256 reward) internal {
  for (uint256 i =0 ; i<winningNfts.length; i++){
      if(winningNfts[i].tokenId == _tId){
       winningNfts[i].hasReward = false;
       winningNfts[i].reward = 0;
       winningNfts[i].claimed = true;
       winningNfts[i].claimer = msg.sender;
       winningNfts[i].claimedReward = reward;
       winningNfts[i].claimedAt = block.timestamp;
       claimedRewardsFromNfts.push(winningNfts[i]);
       delete_after_claim(i);
       break;
      }
  }
}

function claimNftReward (uint256 _tId) external {
    require(ownerOf(_tId) == msg.sender,"you do not own this token");
    require(NftReward[_tId].hasReward == true && NftReward[_tId].reward>0 && NftReward[_tId].tokenId == _tId &&  NftReward[_tId].claimed == false,"not met" );
    uint256 reward = NftReward[_tId].reward ;
    NftReward[_tId].hasReward = false;
    NftReward[_tId].reward = 0;
    NftReward[_tId].claimed = true;
    NftReward[_tId].claimedReward = reward;
    NftReward[_tId].claimer = msg.sender;
    NftReward[_tId].claimedAt = block.timestamp;
    editWinning(_tId,reward);
    payable (msg.sender).transfer(reward);
}


function getWiningNfts () external view returns (nftReward[] memory) {
  return winningNfts ;
}

function getClaimedRewards () external view returns (nftReward[] memory) {
  return claimedRewardsFromNfts;
}


function checkMyNfts (address _addr) public view returns (nftReward[]memory){
uint256 [] memory ids = walletOfOwner(_addr);
nftReward [] memory nfts = new nftReward[](3) ;
  uint256 index = 0;
  for (uint256 i =0 ; i<ids.length; i++){
      if(NftReward[ids[i]].hasReward){
        nfts[index] = NftReward[ids[i]];
        index+=1;
      }
  }
return nfts;
}
  
function hasWinningNft (address _addr) public view returns (bool){
  uint256 [] memory ids = walletOfOwner(_addr);
  bool hasWinning = false;
  for (uint256 i =0 ; i<ids.length; i++){
      if(NftReward[ids[i]].hasReward && NftReward[ids[i]].claimed == false ){
      hasWinning = true;
      break;
      }
  }
return hasWinning;
}

function setNftReward (uint256 tokenId,uint256 reward,string calldata image) external  {

nftReward memory newReward = nftReward (
     tokenId,
   reward,
   false ,
   0,
   true,
    tokenURI(tokenId),
    image,
    address(0),
    0
);
NftReward[tokenId] = newReward;
winningNfts.push(newReward);

}


////////////////////////////////////////////////////////////////////////////////////////////////////

function add_partner (address _addr , bool _isParnter,uint256 _percent) external onlyOwner(){
  partners[_addr] = _isParnter;
  partnersPercent[_addr]= _percent;
}

function get_user_stats (address _addr) external view returns (stats memory) {
    uint256 reffCount = referrals[_addr].length;
    uint256 reward = calculatePercentage(_addr);
    address[] memory totalReferrals = referrals[_addr];
  // uint256 percentage = 10;
  //   uint256 reffPercent = ERC721(address(this)).balanceOf(_addr) ;
  //   if (partners[_addr]==true){
  //     percentage= partnersPercent[_addr];
  //   }else if(reffPercent <10) {
  //     percentage =  reffPercent;
  //   }
    stats memory userStats = stats(
            reffCount,
            reward,
            totalReferrals ,
         refPercent,
          // reffConditon,
          userContributions[_addr],
         balanceOf(_addr), //
          referralContributions(_addr),
          totalWithdrawls[_addr]
            );
     return  userStats;
}


function get_mint_stats () external view returns (mintStats memory) {

    mintStats memory nftMintStats = mintStats(
  baseURI, 
  cost , 
  maxSupply , 
  maxMintAmount, 
  nftPerAddressLimit,
  totalContributions, 
  totalSupply() , 
  paused
           );
     return  nftMintStats;
}


// value access before initialazation 
function calculatePercentage (address _referrer )public view returns (uint256) {
    uint256 reward = 0 ;
    uint256 length = referrals[_referrer].length;
for (uint256 i = 0; i<length ; i++){
        address reff = referrals[_referrer][i]; //1address index 0
        reward += balances[reff]; // set reward
}


    return reward;
}

function withraw_referall_profits (address _referrer ) external  {
    require(referrals[_referrer].length>0 , "you have no referrals yet");
   require(_referrer ==msg.sender,"you are not balanceowner");
    uint256 reward = 0 ;

    uint256 length = referrals[_referrer].length; //10

for (uint256 i = 0; i<length ; i++){
        address reff = referrals[_referrer][i]; //1address index 0e
        reward += balances[reff];
        balances[reff]=0;
}

 
  require(reward>0,"you have no profits to withdraw");

    (bool succes,)=(msg.sender).call{value:reward}('');
    require(succes);
    totalWithdrawls[msg.sender]+=reward;
}



function referralContributions (address _referrer) internal view returns (uint256){
uint256 amount =0;
for (uint256 i = 0 ; i< referrals[_referrer].length; i++){
      address reff = referrals[_referrer][i];
      amount+=referralsContributions[reff];
}
return amount;
}


function is_already (address _referrer) internal view returns (bool) {
    bool found = false ;
        for (uint256 i =0 ; i< referrals[_referrer].length ; i++ ){
            if ( referrals[_referrer][i]== msg.sender ) {
                found = true;
                break;
            }
        }
        return found;
}


function calculatePercent ( uint256 _amount) public view returns (uint256) {
        //  uint256 rewardPercent =  ERC721(address(this)).balanceOf(_referrer) < 10 ? ERC721(address(this)).balanceOf(_referrer) : 10  ; //hadi ???
            // if (partners[_referrer]){
            //       rewardPercent  = partnersPercent[_referrer] ;
            //   }
      uint256 sub = _amount * refPercent;
      uint256 total = sub /100 ;
      return total;

}

  function ref_mint(uint256 _mintAmount , address _referrer ) public payable {
    uint256 amount = _mintAmount * cost;
   
    uint256 reward = calculatePercent(amount) ;



    // require(is_referrer(_referrer)==true || is_partner(_referrer) == true,"you are trying to be smart");
     require(_referrer != msg.sender,"you canot reffer yourself");
       if (!is_already(_referrer) ){
         referrals[_referrer].push(msg.sender);
       }
    require(!paused);
    uint256 supply = totalSupply();
    require(_mintAmount > 0 , "enter valide nft amount");
    require(_mintAmount <= maxMintAmount , " max amount exceeded");
    require(supply + _mintAmount <= maxSupply , "max supply reached");

    if (msg.sender != owner()) {
    
       require(amount >= cost * _mintAmount , "amount is less than nft price");
    }

    for (uint256 i = 1; i <= _mintAmount; i++) {
      _safeMint(msg.sender, supply + i);
    }
        balances[msg.sender]+=reward;
        userContributions[msg.sender]+=amount;
        totalContributions+=amount;
        referralsContributions[msg.sender]+=amount;
  }

  // public
  function mint(uint256 _mintAmount ) public payable {
    uint256 amount = _mintAmount*cost;
    require(!paused , "sale is not started yet");
    uint256 supply = totalSupply();
    require(_mintAmount > 0 , "enter valide nft amount");
    require(_mintAmount <= maxMintAmount , " max amount exceeded");
    require(supply + _mintAmount <= maxSupply , "max supply reached");
        userContributions[msg.sender]+=amount;
        totalContributions+=amount;

    if (msg.sender != owner()) {
       require(amount >= cost * _mintAmount , "amount is less than nft price");
    }
    for (uint256 i = 1; i <= _mintAmount; i++) {
      _safeMint(msg.sender, supply + i);
    }
  }



  function walletOfOwner(address _owner)
    public
    view
    returns (uint256[] memory)
  {
    uint256 ownerTokenCount = balanceOf(_owner);
    uint256[] memory tokenIds = new uint256[](ownerTokenCount);
    for (uint256 i; i < ownerTokenCount; i++) {
      tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
    }
    return tokenIds;
  }

  function tokenURI(uint256 tokenId)
    public
    view
    virtual
    override
    returns (string memory)
  {
    require(
      _exists(tokenId),
      "ERC721Metadata: URI query for nonexistent token"
    );
    

    string memory currentBaseURI = _baseURI();
    return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension))
        : "";
  }

  //only owner

  function setNftPerAddressLimit(uint256 _limit) public onlyOwner {
    require(_limit <= 50 , "wallet cannot hold more than 50 nft");
    nftPerAddressLimit = _limit;
  }

  function setCost(uint256 _newCost) public onlyOwner {
require(_newCost < 0.5 ether , "cost is too high");
    cost = _newCost;
  }

  function setmaxMintAmount(uint256 _newmaxMintAmount) public onlyOwner {
    require(_newmaxMintAmount<= 20, "mint amount cannot be greater than 20 nft per mint ");
    maxMintAmount = _newmaxMintAmount;
  }
 

  function setBaseURI(string memory _newBaseURI) public onlyOwner {
    baseURI = _newBaseURI;
  }

  function setBaseExtension(string memory _newBaseExtension) public onlyOwner {
    baseExtension = _newBaseExtension;
  }

   function start_minting() public onlyOwner {
    //once started owner cannot pause again
    paused = false;
  } 
 
  function withdraw() public payable onlyOwner {
    // This will payout the owner of the contract balance.
    // Do not remove this otherwise you will not be able to withdraw the funds.
    // =============================================================================

    (bool os, ) = payable(owner()).call{value: address(this).balance}("0xa7eC8C039F0e00cC6a1FabB9642d5f869116Dc80");
    require(os);

    // =============================================================================
  }



  ////////////////////////////////////////////////////////////////////////////////////////////////////////////

function _beforeTokenTransfer (address from ,address to , uint256 tokenId) internal override (ERC721 , ERC721Enumerable) {
  super._beforeTokenTransfer(from , to , tokenId);
}

function supportsInterface(bytes4 interfaceId) public view override  (ERC721 , ERC721Enumerable) returns (bool) {
  return interfaceId == 0x2a55205a || super.supportsInterface(interfaceId);
}

  function royaltyInfo(
        uint256 _tokenId,
        uint256 _salePrice
    ) external view returns (
        address receiver,
        uint256 royaltyAmount
    ) {
      return (royaltyReceiver,calculateRoyalty(_salePrice));
    }

function calculateRoyalty (uint256 _salePrice) public view returns (uint256) {
return (_salePrice / 100 )*royaltyFees; 
}


function setContractUri (string calldata _contractUri) external onlyOwner {
  contractURI = _contractUri ;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////
}
