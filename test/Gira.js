const Girasol = artifacts.require("Girasol");
const daiABI = require("../build/contracts/EIP20.json").abi;
let gira;
let dai;

contract("Girasol", async accounts => {

    before(async function() {
        gira = await Girasol.deployed();
        let daiAddress = await gira.dai_ropsten();
        dai = new web3.eth.Contract(daiABI, daiAddress);
    });

    it("changeProtocol() should work as expected", async () => {
        let selectedProtocol = (await gira.selected_protocol.call()).toString(); 
        assert.equal(selectedProtocol, "0", "selected_protocol should be 0 on deploy");
        
        await gira.changeProtocol(1);
        selectedProtocol = (await gira.selected_protocol.call()).toString();
        assert.equal(selectedProtocol, "1", "selected_protocol should be 0 on deploy");

        // There must be some better way to handle errors
        let error = false;
        try {
            await gira.changeProtocol(2);
        } catch (e) {
            error = true;
        }
        assert.isTrue(error, "Selecting a invalid protocol should fail");

        error = false;
        try {
            await gira.changeProtocol(1, {from: accounts[1]});
        } catch (e) {
            error = true;
        }
        assert.isTrue(error, "Setting the protocol from a non owner should fail");

        await gira.changeProtocol(0);
    })

    it("add() should fail when transferFrom fails", async () => {
        let error = false;
        try {
            await gira.add(1).send();    
        } catch (e) {
            error = true;
        }
        assert.isTrue(error, "Should have thrown error");
    })

    it("add() should work", async() => {


    })


})