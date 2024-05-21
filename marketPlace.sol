// SPDX-License-Identifier: MIT LICENSE
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// --- buggs --- //
// cancel bid removes bid if it was highest , the highest won't update



contract TwiMarket is IERC721Receiver, ReentrancyGuard, Ownable {

   ERC721Enumerable nft;
    constructor(ERC721Enumerable _nft) {
        holder = payable(msg.sender);
        nft = _nft;
    }


    receive() external payable {
        leftovers+=msg.value;
    }

    function onERC721Received(
        address,
        address from,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        require(from == address(0x0), "Cannot send nfts to Vault directly");
        return IERC721Receiver.onERC721Received.selector;
    }

    address payable holder;
    uint256 listingFee = 0.025 ether;
    uint256 auctionFees = 0.025 ether;
    uint256 platformFunds = 0;
    uint256 leftovers = 0 ;
//---------------------------- structs --------------------------------//
    struct List {
        uint256 tokenId;
        string name;
        address payable seller;
        address payable holder;
        uint256 price;
        string metadata_url;
        string image;
        uint256 listedAt;
        bool sold;
    }
    struct NftData {
        offer[] Offers;
        List nftData;
    }

    struct offer {
        uint256 tokenId;
        address offerer;
        uint256 price;
        uint256 offeredAt;
    }
    mapping(uint256 => offer[]) public Offers;
    mapping(uint256 => List) public listedNfts;

    uint256 public listingCount = 0;
    uint256[] public activeListingIds;
    uint256[] public activeAuctionIds;

//------------------------------------------------------------------ auction system -------------------------------------------------------------------------//
    
    struct bid {
        uint256 tokenId;
        address bidder;
        uint256 price;
        uint256 bidsAt; // time
    }

    struct auction {
        uint256 tokenId;
        string name;
        address payable seller;
        address payable holder;
        uint256 floorPrice;
        string metadata_url;
        string image;
        uint256 listedAt;
        uint256 startsAt; // time to start auction
        uint256 endsAt;  // time to end auction
        uint256 highestBid;
        address highestBidder;
        uint256 buyNow;
    }

    mapping(uint256 => auction) public auctionByTokenId; // token id to nft auction
    mapping(uint256 => bid[]) public bids; // token id to array of auction bids

struct tokenAuction {
bid[] allBids;
auction Auction;
}
struct tokenListing {
offer[] Offers;
List listing;
}

struct userListings {
 auction[] userAuctions;
 List[] userListings;   
}

struct checkListed {
uint256 tokenId;
bool listed;
string listingsType;
address owner;
uint256 price;
uint256 buyNow;
}
modifier started (uint256 _tId) {
    require(block.timestamp >= auctionByTokenId[_tId].startsAt && block.timestamp < auctionByTokenId[_tId].endsAt , "not right  time");
    _;
} 
//-------------------------------------------------- auction system ----------------------------------------------------------//
                                //------------------ auction Crud -------------------------//

function createAuction ( uint256 _tId ,uint256 _floorPrice ,string calldata _img,string calldata _name, uint256 _startTime,uint256 _endTime,uint256 _buyprice)public payable {    
         require(nft.ownerOf(_tId) == msg.sender, "you are not the owner !");
        require(listedNfts[_tId].tokenId == 0, "NFT already listed");
        require(auctionByTokenId[_tId].tokenId == 0, "NFT already listed");
        // require(_floorPrice > 0, "Amount must be higher than 0"); // floor price can be set to 0
        if (Offers[_tId].length >0 ){
            withdrawOffers(_tId);
        }
        auctionByTokenId[_tId] = auction (
            _tId,
            _name,
            payable(msg.sender),
            payable(address(this)),
            _floorPrice,
            nft.tokenURI(_tId),
            _img,
            block.timestamp,
            _startTime,
            _endTime,
            0,
            address(0),
        _buyprice
        );
        require(msg.value>= auctionFees,"Listing fees required");

        nft.transferFrom(msg.sender, address(this), _tId);
        activeAuctionIds.push(_tId);
        platformFunds+=msg.value;
        listingCount += 1;
}


function buyNowAuction (uint256 _tId ) public payable started ( _tId) {
    // require(auctionByTokenId[_tId].price>=)
    require(auctionByTokenId[_tId].tokenId == _tId ,"not auction item");
    auction memory auc = auctionByTokenId[_tId];
    require(msg.value >= (auc.highestBid + auc.buyNow),"amount is less than buy now price");
    uint256 amount = (auc.highestBid+auc.buyNow);
    require(auc.buyNow>0,"available for auction only");
                 nft.transferFrom(address(this), msg.sender, _tId);
                      payable(auc.seller).transfer(amount);
                         withdrawBids(_tId);
                         f_auc(_tId);
                                        }
function cancelAuction (uint256 _tId) external   {
    address sdr = _msgSender();
     auction memory auc = auctionByTokenId[_tId]; // auction instance
         if (auc.endsAt < block.timestamp && auc.highestBid > 0 ){
                 address winner = auc.highestBidder;
                 require(sdr== auc.seller  || sdr == winner, "not auction owner");     
                 nft.transferFrom(address(this), winner, _tId);
                 payable(auc.seller).transfer(auc.highestBid);
                 del_bids_onBuy(_tId,winner); 
                 f_auc(_tId);
           } else {
                require(sdr == auc.seller, "not auction owner");
                nft.transferFrom(address(this), sdr, _tId);
                withdrawBids(_tId); // withdraw all bids and delete all bids
                f_auc(_tId);
           }
    }
function addBid (uint256 _tId, uint256 _price) external payable started ( _tId) {
    require(auctionByTokenId[_tId].tokenId != 0 ,"not auction item");
    bool isBid = userBided(_tId);
    uint256 val = msg.value;
    address sender = _msgSender();
    if (isBid){
      updateBid(_tId,val);

        } else {
    require(val > auctionByTokenId[_tId].highestBid && val > auctionByTokenId[_tId].floorPrice ,"your bid is less than highest" );
        bid memory newBid = bid(
            _tId,
            sender,
            _price,
            block.timestamp
        );
        bids[_tId].push(newBid);
        auctionByTokenId[_tId].highestBid = val;
        auctionByTokenId[_tId].highestBidder = sender;
        }
}
function acceptBid(uint256 _tId, uint256 _index) external {
        address bidder = bids[_tId][_index].bidder;
        uint256 price = bids[_tId][_index].price;
        address sdr = _msgSender() ;
        require(auctionByTokenId[_tId].seller == sdr , "you are not auction creator");
            payable(sdr).transfer(price);
            nft.transferFrom(address(this), bidder, _tId);
            del_bids_onBuy(_tId,bidder);
            f_auc(_tId);
    }
//-------------------------------------------------- auction system helpers & utils ----------------------------------------------------------//
function userBided(uint256 _tId) public view returns (bool) {
        uint256 lng = bids[_tId].length;
        for (uint256 i = 0; i < lng; i++) {
            if (bids[_tId][i].bidder == msg.sender) {
                return true; // User has made at least one offer for the token
            }
        }
        return false; // User has not made any offers for the token
    }
function bidder_index (uint256 _tId , address _addr)internal view  returns (uint256){
            uint256 idx = 0 ;
             uint256 l = bids[_tId].length;
     for (uint256 i =0 ; i<l ; i++){
                    if (bids[_tId][i].bidder == _addr){
                            idx = i ;
                     break;       
                    }}
    return idx;
    }
    function del_auction_id(uint256 _tId) internal {
        // Mark the listing as sold to prevent further actions
        // Remove the listing ID from the activeListingIds array
        for (uint256 i = 0; i < activeAuctionIds.length; i++) {
            if (activeAuctionIds[i] == _tId) {
                activeAuctionIds[i] = activeAuctionIds[
                    activeAuctionIds.length - 1
                ];
                activeAuctionIds.pop();
                break;
            }
        }
    }
    
    // finalize auction
function f_auc (uint256 _tId) internal {
            delete auctionByTokenId[_tId];
            del_auction_id(_tId);
            listingCount-=1;
}
function del_bids_onBuy (uint256 _tId,address _addr) internal {
        uint256 l = bids[_tId].length;
         if (l>0){
            uint256 _index = bidder_index(_tId,_addr);
            uint256 lI = bids[_tId].length-1;
            bids[_tId][_index] = bids[_tId][lI];
            bids[_tId].pop();
            }
            withdrawBids(_tId);
}
function withdrawBids (uint256 _tId) internal {
    for (uint256 i =0 ; i<bids[_tId].length;i++){
        uint256 val = bids[_tId][i].price;
        address rec = bids[_tId][i].bidder;
        payable(rec).transfer(val);
    }
    delete bids[_tId];
    }

function updateBid (uint256 _tId, uint256 _price)internal {
     for (uint256 i =0; i< bids[_tId].length;i++){
        if ( bids[_tId][i].bidder == msg.sender){
            uint256 newVal = bids[_tId][i].price + _price;
            require(newVal >auctionByTokenId[_tId].highestBid, "your bid is lower than highest" );
            auctionByTokenId[_tId].highestBid = newVal;
            auctionByTokenId[_tId].highestBidder = msg.sender;
            bids[_tId][i].price = newVal;
        break;
        }
       }
}
//-------------------------------------------------- auction system getters ----------------------------------------------------------//


function getAuctionData (uint256 _tId) external view returns (tokenAuction memory){
    tokenAuction memory nftAuctionDetails = tokenAuction(
        bids[_tId],
        auctionByTokenId[_tId]
    );
return nftAuctionDetails ;
}


 function getActiveUserAuctions(address _user)
        public
        view
        returns (auction[] memory)
    {
        auction[] memory res = new auction[](activeAuctionIds.length);
        for (uint256 i = 0; i < activeAuctionIds.length; i++) {
            uint256 tokenId = activeAuctionIds[i];
            if (auctionByTokenId[tokenId].seller == _user) {
                res[i] = auctionByTokenId[tokenId];
            }
        }
        return res;
    }
//____________________________________________________________________________________________________________________________________________________//




//-------------------------------------------------- listing system crud ----------------------------------------------------------//
 
function listSale(
        uint256 _tId,
        uint256 _price,
        string memory _img,
        string memory _name
    ) public payable nonReentrant {
        require(nft.ownerOf(_tId) == msg.sender, "you are not the owner !");
        require(listedNfts[_tId].tokenId == 0, "NFT already listed");
        require(_price > 0, "Amount must be higher than 0");
        require(msg.value == listingFee, "Listing require platform fees ");
        listedNfts[_tId] = List(
            _tId,
            _name,
            payable(msg.sender),
            payable(address(this)),
            _price,
            nft.tokenURI(_tId),
            _img,
            block.timestamp,
            true
        );
        nft.transferFrom(msg.sender, address(this), _tId);
        listingCount += 1;
        activeListingIds.push(_tId);
    }
function buyNft(uint256 _tId) public payable nonReentrant {
        address sdr = _msgSender();
        uint256 val = listedNfts[_tId].price;
        require( msg.value >= val,"Transfer Total Amount to complete transaction");
        listedNfts[_tId].seller.transfer(val);
        nft.transferFrom(address(this), sdr, _tId);
        if (Offers[_tId].length >0){
        withdrawOffers(_tId);
        f_listing(_tId);
        }else {
        f_listing(_tId);
        }
    }
 function editListing(uint256 _newPrice, uint256 _id) external {
        require(
            listedNfts[_id].price != _newPrice,
            "same price :( please choose other value"
        );
        require(listedNfts[_id].seller == msg.sender);
        listedNfts[_id].price = _newPrice;
    }
function cancelListing(uint256 _tId) public {
        require(listedNfts[_tId].seller == msg.sender, "NFT not yours");
        nft.transferFrom(address(this), msg.sender, _tId);      
        if (Offers[_tId].length >0){
        withdrawOffers(_tId);
        f_listing(_tId);
        }else{
        f_listing(_tId);  
        }
    }

 function makeOffer(uint256 _tId, uint256 _price) external payable   {
        bool isOf = userOffered(_tId);
        require(_price > 0, "price must be higher than 0");
        if (isOf){
        update_offer(_tId,_price);
        }else {
        require(msg.value>=_price  , "value is incorrect");
 offer memory newOffer = offer(
           _tId,
            msg.sender, // The address of the person making the offer
            _price,
           block.timestamp
            );
        Offers[_tId].push(newOffer);
        }
    }
function acceptOffer(uint256 _tId, uint256 _index) external {
        address o = Offers[_tId][_index].offerer;
        uint256 val = Offers[_tId][_index].price;
        address sdr = _msgSender();
        if (listedNfts[_tId].seller == sdr) {
            // require(userOffered(_tId)== true , "user has no offer");
            payable(sdr).transfer(val);
            nft.transferFrom(address(this), o, _tId);
            del_offers_onBuy(_tId,_index);
            f_listing(_tId); // finalize listing delets listing and its id
            
        } else if (nft.ownerOf(_tId) == sdr) {
            nft.transferFrom(sdr, o, _tId);
            require(payable(sdr).send(val));
             del_offers_onBuy(_tId,_index);  
        }
    }
 function deletOffer(uint256 _tId) external {
        require(userOffered(_tId) == true, "you have No active offers");
        uint256 length = Offers[_tId].length;
        for (uint256 i = 0; i < length; i++) {
            if (Offers[_tId][i].offerer == msg.sender) {
                uint256 am = Offers[_tId][i].price;
                Offers[_tId][i]= Offers[_tId][(length-1)];
                Offers[_tId].pop();
                payable(msg.sender).transfer(am);
                break;
            }
        }
    }
//-------------------------------------------------- listing system getters ----------------------------------------------------------//
// function getListingData (uint256 _tId) external view returns (tokenListing memory){
//     tokenListing memory listing = tokenListing(
//         Offers[_tId],
//         listedNfts[_tId]
//     );
//     return listing ;
//     }

// function getNftDetails (uint256 _tId) external view returns (NftData memory){
//     NftData memory nftDetails = NftData(
//         Offers[_tId],
//         listedNfts[_tId]

//     );
//     return nftDetails;
//     }

   function getAllOffersForToken(uint256 _tId) external view returns (offer[] memory){
        return Offers[_tId];
    }
        function getActiveUserListings(address _user) public view returns (List[] memory) {
        List[] memory res = new List[](activeListingIds.length);
        for (uint256 i = 0; i < activeListingIds.length; i++) {
            uint256 tokenId = activeListingIds[i];
            if (listedNfts[tokenId].seller == _user) {
                res[i] = listedNfts[tokenId];
            }
        }
        return res;
    }
//-------------------------------------------------- listing system helpers & utils ----------------------------------------------------------//
function update_offer (uint256 _tId, uint256 _price)internal {
     for (uint256 i =0; i< Offers[_tId].length;i++){
        if ( Offers[_tId][i].offerer == msg.sender){
            require(msg.value >= (_price - Offers[_tId][i].price) , "incorrect update value" );
            Offers[_tId][i].price = _price;
        break;
        }
       }
}
//used in ui
function is_listed(uint256 _tId) external view returns (checkListed memory) {
    checkListed memory checkListing =  checkListed(
            _tId,
            false,
            "not-listed",
            nft.ownerOf(_tId),
            0,
            0
        ); 

    if (listedNfts[_tId].tokenId==_tId){
        checkListing = checkListed(
            _tId,
            true,
            "listing",
            listedNfts[_tId].seller,
            listedNfts[_tId].price,
            0
  ); 
}
    if (auctionByTokenId[_tId].tokenId==_tId){
        checkListing = checkListed(
            _tId,
            true,
            "auction",
             auctionByTokenId[_tId].seller,
             auctionByTokenId[_tId].highestBid,
             auctionByTokenId[_tId].buyNow
        );
    }
return checkListing;
}

 function userOffered(uint256 _tId ) public view returns (bool) {
        uint256 length = Offers[_tId].length;
        for (uint256 i = 0; i < length; i++) {
            if (Offers[_tId][i].offerer == msg.sender) {
                return true; // User has made at least one offer for the token
            }
        }
        return false; // User has not made any offers for the token
    }
    function del_listing_id(uint256 _tId) internal {
        // Mark the listing as sold to prevent further actions
        // Remove the listing ID from the activeListingIds array
        for (uint256 i = 0; i < activeListingIds.length; i++) {
            if (activeListingIds[i] == _tId) {
                activeListingIds[i] = activeListingIds[
                    activeListingIds.length - 1
                ];
                activeListingIds.pop();
                break;
            }
        }
    }
function del_offers (uint256 _tId)internal {
    for (uint256 i =0 ; i<Offers[_tId].length;i++){
        payable(Offers[_tId][i].offerer).transfer(Offers[_tId][i].price);
    }
}
function f_listing (uint256 _tId) internal {
            delete listedNfts[_tId];
            del_listing_id(_tId);
            listingCount-=1;
}
function del_offers_onBuy (uint256 _tId, uint256 _index) internal {
        uint256 l = Offers[_tId].length;
         if (l>0){
            uint256 lI = Offers[_tId].length-1;
            Offers[_tId][_index] = Offers[_tId][lI];
            Offers[_tId].pop();
            }
            withdrawOffers(_tId);
}
function withdrawOffers (uint256 _tId) internal {
    for (uint256 i =0 ; i<Offers[_tId].length;i++){
        uint256 val = Offers[_tId][i].price;
        address rec = Offers[_tId][i].offerer;
        payable(rec).transfer(val);
    }
delete Offers[_tId];
}

//----------------------------------------------------------------- UI functions ------------------------------------------------------------------------//

//getter for user listings and user auctions => user listings page UI // error fixed
function getAllUserListings (address _addr) external view returns (userListings memory) {
    userListings memory allUserListings = userListings(
        getActiveUserAuctions(_addr),
        getActiveUserListings(_addr)
    );
    return allUserListings;
}



function getAllAuctions () external view returns (auction[] memory) {
   uint256 l = activeAuctionIds.length;
    uint256 tokenId = 0 ;
    auction[] memory allAuctions =new auction[](l) ;
    for(uint256 i=0 ; i< activeAuctionIds.length; i++){
        tokenId = activeAuctionIds[i];
      allAuctions[i] = auctionByTokenId[tokenId];
    }
    return allAuctions ;
}
function getAllListings () external view returns (List[] memory) {
   uint256 l = activeListingIds.length;
    uint256 tokenId = 0 ;
    List[] memory allListings =new List[](l) ;
    for(uint256 i=0 ; i< activeListingIds.length; i++){
        tokenId = activeListingIds[i];
      allListings[i] = listedNfts[tokenId];
    }
    return allListings ;
}


//--------------------------------------------------------------------------------------------------------------------------------------------------------//

    // function getActiveListings() public view returns (List[] memory) {
    //     List[] memory res = new List[](activeListingIds.length);
    //     for (uint256 i = 0; i < activeListingIds.length; i++) {
    //         uint256 _tId = activeListingIds[i];
    //         res[i] = listedNfts[_tId];
    //     }
    //     return res;
    // }


    function getListingFee() public view returns (uint256) {
        return listingFee;
    }

    function getPrice(uint256 tokenId) public view returns (uint256) {
        uint256 price = listedNfts[tokenId].price;
        return price;
    }



    function withdraw_profits() public payable onlyOwner {
        require(platformFunds > 0 , " platform has no profits");
        require(payable(msg.sender).send(platformFunds));
        platformFunds = 0 ;
    }

    function withdraw_leftovers() public payable onlyOwner {
        require(payable(msg.sender).send(leftovers));
        leftovers = 0 ;
    }

    function withdraw_all() public payable onlyOwner {
        require(payable(msg.sender).send(address(this).balance));
        platformFunds = 0 ;
        leftovers = 0 ;
    }

    function withdraw_erc20 (address _token , uint256 _amount) external onlyOwner() {
       if (_amount == 0 ){
        uint256 balance = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transfer(_msgSender(),balance);
       } else {
        IERC20(_token).transfer(_msgSender(),_amount);
       }
    }



    function setNft(ERC721Enumerable _nft)external onlyOwner{
        nft = _nft;
    }

    function setListingFees(uint256 _fee) external onlyOwner {
        require(
            listingFee != _fee,
            "listing fees are the same please choose other value"
        );
        listingFee = _fee;
    }
    function setAuctionFees(uint256 _fee) external onlyOwner {
        require(
            auctionFees != _fee,
            "listing fees are the same please choose other value"
        );
        listingFee = _fee;
    }

    function getNftMetadata(uint256 _id) public view returns (string memory) {
        return nft.tokenURI(_id);
    }

}
