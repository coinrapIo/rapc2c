pragma solidity ^0.4.24;

import "ds-test/test.sol";
import "ds-math/math.sol";
import "ds-token/token.sol";
import "./Offer.sol";
import "./C2CMkt.sol";
import "./CoinRapGateway.sol";

contract C2CMktTest is DSTest {
    
    DSToken crp;
    C2CMkt c2c;
    OfferData offer_data;
    CoinRapGateway gateway;
    uint startsWith = 0;
    uint initialBalance = 100000 * 10 ** 18;
    uint user1CrpAmnt = 10000*10**18;
    DSToken constant internal ETH_TOKEN_ADDRESS = DSToken(0x00eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee);
    DSToken constant internal WETH_TOKEN_ADDR = DSToken(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address user1 = address(0x897eeaF88F2541Df86D61065e34e7Ba13C111CB8);
    address fee_wallet = address(0x0fc7ebf20B23437E359Bba1D214a4ED0ad72f577);
    

    function setUp() public 
    {
        offer_data = new OfferData(startsWith);
        c2c = new C2CMkt(offer_data);
        offer_data.set_c2c_mkt(c2c);

        gateway = new CoinRapGateway();
        gateway.set_c2c_mkt(c2c);
        gateway.set_offer_data(offer_data);
        c2c.setCoinRapGateway(gateway);


        crp = new DSToken("CRP");
        c2c.setToken(crp, true);
        crp.mint(initialBalance);

        user1.transfer(5*10**18);  // test -5eth-> user1
        crp.transfer(user1, user1CrpAmnt); //
    }

    function () public payable
    {
    }

    function test_make() public
    {

        uint _srcAmnt = 10**18;
        uint _destAmnt = 1000 * 10**18;
        uint _min = _destAmnt;
        uint _max = _destAmnt;
        uint _fee = 10*10**14;
        uint16 _code = 1234;
        // bytes memory _ref;
        // DSToken src, uint src_amnt, DSToken dest, uint dest_amnt, 
        // uint prepay, uint rng_min, uint rng_max, uint16 code, bytes ref
        uint id = gateway.make.value(_srcAmnt+_fee)(ETH_TOKEN_ADDRESS, _srcAmnt, crp, _destAmnt, _min, _max, _code);
        assertEq(id, startsWith+1);
        validate_offer(id, ETH_TOKEN_ADDRESS, _srcAmnt, crp, _destAmnt, _min, _max, _code);
        // DSToken src, uint srcAmnt, DSToken dest, uint destAmnt, 
        // address owner, uint min, uint max, bool hasCode, uint16 code
        // DSToken src;
        // DSToken dest;
        // uint srcAmnt; 
        // uint destAmnt;
        // uint min;
        // uint max;
        // address owner;
        // uint16 code;
        // bool hasCode;

        // (src, srcAmnt,  dest, destAmnt, owner, min, max, hasCode, code) = mkt.getOffer(id);
        // assertTrue(src == ETH_TOKEN_ADDRESS);
        // assertTrue(dest == crp);
        // assertEq(srcAmnt, _srcAmnt);
        // assertEq(destAmnt, _destAmnt);
        // assertEq(owner, address(this));
        // assertEq(min, _min);
        // assertEq(max, _max);
        // assertTrue(hasCode == (_code > 0));
        // assertTrue(code == _code);
        assertEq(offer_data.getOfferCnt(this), 1);
        assertTrue(offer_data.isActive(id));
        assertEq(offer_data.getOwner(id), address(this));
        // uint id, uint destAmnt, uint rngMin, uint rngMax, uint16 code
        c2c.update(id, _destAmnt, _min, _max, 0);
        uint amnt;
        uint fee;
        (amnt, fee) = c2c.cancel(id);
        assertEq(amnt -_fee, _srcAmnt);
        assertEq(fee, _fee);

    }

    function test_make_take() public
    {
        uint _srcAmnt = 10**18;
        uint _destAmnt = 1000 * 10**18;
        uint _min = 5*10**17;
        uint _max = _destAmnt;
        uint _fee = 10*10**14;
        uint16 _code = 1234;
        uint take_amnt=0;
        // bytes memory _ref;
        // DSToken src, uint src_amnt, DSToken dest, uint dest_amnt, 
        // uint prepay, uint rng_min, uint rng_max, uint16 code, bytes ref
        uint id = c2c.make.value(_srcAmnt+_fee)(user1, ETH_TOKEN_ADDRESS, _srcAmnt, crp, _destAmnt, _min, _max, _code);
        assertEq(id, startsWith+1);
        assertEq(crp.balanceOf(this), initialBalance-user1CrpAmnt);
        assertTrue(crp.approve(address(gateway), 2**255));
        (take_amnt, _fee) = gateway.take.value(0)(id, ETH_TOKEN_ADDRESS, crp, _destAmnt, 1000*10**9, _code, 0);
        assertEq(crp.balanceOf(this), initialBalance-user1CrpAmnt-_destAmnt);
        assertEq(address(c2c).balance, _fee);
        c2c.approvedWithdrawAddress(ETH_TOKEN_ADDRESS, fee_wallet,true);
        uint bal = fee_wallet.balance;
        c2c.withdraw(ETH_TOKEN_ADDRESS, _fee, fee_wallet);
        assertEq(fee_wallet.balance, bal + _fee);
        assertEq(take_amnt, _srcAmnt);
        assertEq(_fee, 10*10**14);
        
    }

    function test_make_take_token_to_eth() public
    {
        uint _src_amnt = 1000 * 10 ** 18; //token
        uint _dest_amnt = 10**18; //eth
        uint _min = 5 * 10 **17;
        uint _max = _dest_amnt;
        uint _fee = 10 * 10 ** 14;
        uint16 _code = 1234;

        uint rate = c2c.calcWadRate(_src_amnt, 18, _dest_amnt, 18);
        assertEq(rate, 10**15);

        crp.approve(address(gateway), 2**255);
        // uint id = gateway.make.value(0)(crp, _src_amnt, ETH_TOKEN_ADDRESS, _dest_amnt, _min, _max, _code);
        crp.transfer(c2c, _src_amnt);
        uint id = c2c.make.value(0)(user1, crp, _src_amnt, ETH_TOKEN_ADDRESS, _dest_amnt, _min, _max, _code);
        assertEq(_src_amnt, crp.balanceOf(c2c));
        assertEq(id, startsWith+1);
        
        (_dest_amnt, _fee) = gateway.take.value(7*10**17)(id, crp, ETH_TOKEN_ADDRESS, 7*10**17, 10**15, _code, 0);
        assertEq(1000 * 10 ** 18 - _dest_amnt, crp.balanceOf(c2c));
        assertEq(_dest_amnt, 700*10**18);
        assertEq(_fee, 4*10**14);

        (_dest_amnt, _fee) = gateway.take.value(3*10**17)(id, crp, ETH_TOKEN_ADDRESS, 3*10**17, 10**15, _code, 0);
        assertEq(0, crp.balanceOf(c2c));
        assertEq(_dest_amnt, 300*10**18);
        assertEq(_fee, 6*10**14);

    }

    function validate_offer(uint id, DSToken _src, uint _srcAmnt, DSToken _dest, uint _destAmnt, uint _min, uint _max, uint16 _code) internal
    {
        // DSToken src;
        // DSToken dest;
        uint srcAmnt; 
        uint destAmnt;
        uint min;
        uint max;
        address owner;
        // uint16 code;
        // bool hasCode;

        (, srcAmnt,  , destAmnt, owner, min, max, , , ) = offer_data.getOffer(id);
        // assertTrue(src == ETH_TOKEN_ADDRESS);
        // assertTrue(dest == crp);
        assertEq(srcAmnt, _srcAmnt);
        assertEq(destAmnt, _destAmnt);
        assertEq(owner, address(this));
        assertEq(min, _min);
        assertEq(max, _max);
        // assertTrue(hasCode == (_code > 0));
        // assertTrue(code == _code);
    }

    function test_update() public
    {
        uint _src_amnt = 1000 * 10 ** 18; //token
        uint _dest_amnt = 10**18; //eth
        uint _min = 5 * 10 **17;
        uint _max = _dest_amnt;
        // uint _fee = 5 * 10 ** 14;
        uint16 _code = 1234;

        uint rate = c2c.calcWadRate(_src_amnt, 18, _dest_amnt, 18);
        assertEq(rate, 10**15);

        crp.approve(address(gateway), 2**255);
        // uint id = gateway.make.value(0)(crp, _src_amnt, ETH_TOKEN_ADDRESS, _dest_amnt, _min, _max, _code);
        crp.transfer(c2c, _src_amnt);
        uint id = c2c.make.value(0)(user1, crp, _src_amnt, ETH_TOKEN_ADDRESS, _dest_amnt, _min, _max, _code);
        assertEq(_src_amnt, crp.balanceOf(c2c));
        assertEq(id, startsWith+1);

        bool has_code;

        (, _src_amnt,  , _dest_amnt, user1, _min, _max, has_code, , ) = offer_data.getOffer(id);
        assertTrue(has_code);

        //uint id, uint destAmnt, uint rngMin, uint rngMax, uint16 code
        require(c2c.update(id, _dest_amnt, _min, _max, 0));

        (, _src_amnt,  , _dest_amnt, user1, _min, _max, has_code, , ) = offer_data.getOffer(id);
        assertTrue(!has_code);


    }
}
