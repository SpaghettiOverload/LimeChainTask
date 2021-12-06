// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

contract TechnoLimeStore {

    constructor() { 
        owner = msg.sender; 
    }

    // constants
    uint8 constant private RETURN_LIMIT = 100;
    string constant private UNAUTHORIZED = "Unauthorized";
    string constant private NO_SUCH_PRODUCT = "No such product";
    string constant private NOT_ENOUGH_QUANTITY = "Not enough quantity";
    string constant private ALREADY_PURCHASED = "Product already purchased";
    string constant private PAST_DUE_RETURN_DATE = "You are past due return date";
    string constant private NO_RECORD_OF_A_PURCHASE = "You haven't purchased this product";
        
    // variables
    address owner;
    uint private productIds;
    address[] private customers;
    event LogCondition(string condition);
    mapping (uint => Product) private products;
    mapping (string => inStock) private product;
    mapping (address => mapping(uint => Purchase)) private buyers;
    

    // custom modifiers
    modifier onlyOwner {
        require(msg.sender == owner, UNAUTHORIZED);
        _;
    }

    // models     
    struct inStock {
        bool exists;
        uint id;
    }

    struct Product {
        uint id;
        string productName;
        uint qty;
    }

    struct Purchase { 
         Product product;
         uint purchasedAt;
    }

    // functions

    // addProduct updates product quantity if a product already exists or creates new entry if not.
    function addProduct(string memory _productName, uint _qty) external onlyOwner {
        if (product[_productName].exists) {
            uint id = product[_productName].id;
            products[id].qty += _qty;
        } else {
            uint newId = productIds+1;
            products[newId] = Product(newId, _productName, _qty);
            product[_productName].exists = true;
            product[_productName].id = productIds + 1;
            productIds++;
        }
    }

    // buyProduct handles buying a product by checking for product availability and creating records for the successfull sale. 
    function buyProduct(uint _desiredId, uint _desiredQty) external {
        address buyerAddress = msg.sender;
        require(_desiredId > 0 && _desiredId <= productIds, NO_SUCH_PRODUCT);
        require(products[_desiredId].qty >= _desiredQty, NOT_ENOUGH_QUANTITY);
        require(!isPurchased(buyerAddress, _desiredId), ALREADY_PURCHASED);

        Product memory purchasedProduct = products[_desiredId];

        products[_desiredId].qty -= _desiredQty;
        purchasedProduct.qty = _desiredQty;

        Purchase memory purchase = Purchase(purchasedProduct, block.number);
        buyers[buyerAddress][_desiredId] = purchase;
        customers.push(msg.sender);

        string memory purchaseResult = string(abi.encodePacked("Successfull purchase of", purchasedProduct.productName));
        emit LogCondition(purchaseResult);
    }

    // returnProduct validates the given return information and updates the records if successfull.
    function returnProduct(uint _desiredId, uint _desiredQty) external { 
        address buyerAddress = msg.sender;
        require(_desiredId > 0 && _desiredId <= productIds, NO_SUCH_PRODUCT);
        require(isPurchased(buyerAddress, _desiredId), NO_RECORD_OF_A_PURCHASE);
        require(isWithinReturnLimit(buyerAddress, _desiredId), PAST_DUE_RETURN_DATE);
        
        buyers[buyerAddress][_desiredId].product.qty -= _desiredQty;
        products[_desiredId].qty += _desiredQty;

        string memory returnResult = string(abi.encodePacked("Successfull return of ", products[_desiredId].productName));
        emit LogCondition(returnResult);
    }

    // isPurchased checks whether the given buyers address is already associated with a product by the given id.
    function isPurchased(address _address, uint _desiredId) private view returns (bool) { 
        return buyers[_address][_desiredId].purchasedAt > 0;
    }

    // isWithinReturnLimit checks whether a return is within the limits.
    function isWithinReturnLimit(address _address, uint _desiredId) private view returns (bool) {
        return buyers[_address][_desiredId].purchasedAt + RETURN_LIMIT >= block.number;                
    }

    /*
    showProducts displays all available products by returning an array of the products from the products map. 
    Well, I kinda wanted to not do it that way and skip looping for gas saving purposes...
    but I was not quite sure about how to handle data return and what exactly the task expects by 
    "Buyers (clients) should be able to see the available products", because if I simply have left products map public, 
    it won't show all products on call without index to be inserted and a buyer can't know the available indexes if haven't seen available items before.
    */
    function showProducts() external view returns (Product[] memory) {
        Product[] memory results = new Product[](productIds);
        for (uint i=0; i<productIds; i++) {
            results[i] = products[i+1];
        }
        return results;
    }

    // showCustomers returns the addresses of all customers ever successfully completed a purchase.
    function showCustomers() external view returns (address[] memory) {
        return customers;
    }
}
