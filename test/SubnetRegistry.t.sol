// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.19;

import {EMPTY_BYTES} from "../src/constants/Constants.sol";
import {ConsensusType} from "../src/enums/ConsensusType.sol";

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {TestUtils} from "./TestUtils.sol";
import {IDiamond} from "../src/interfaces/IDiamond.sol";

import {SubnetActorGetterFacet} from "../src/subnet/SubnetActorGetterFacet.sol";
import {SubnetActorManagerFacet} from "../src/subnet/SubnetActorManagerFacet.sol";
import {SubnetActorDiamond} from "../src/SubnetActorDiamond.sol";
import {SubnetID} from "../src/structs/Subnet.sol";
import {SubnetRegistryDiamond} from "../src/SubnetRegistryDiamond.sol";
import {SubnetIDHelper} from "../src/lib/SubnetIDHelper.sol";

//facets
import {RegisterSubnetFacet} from "../src/subnetregistry/RegisterSubnetFacet.sol";
import {SubnetGetterFacet} from "../src/subnetregistry/SubnetGetterFacet.sol";
import {DiamondLoupeFacet} from "../src/diamond/DiamondLoupeFacet.sol";
import {DiamondCutFacet} from "../src/diamond/DiamondCutFacet.sol";

contract SubnetRegistryTest is Test {
    using SubnetIDHelper for SubnetID;

    address private constant DEFAULT_IPC_GATEWAY_ADDR = address(1024);
    uint64 constant DEFAULT_CHECKPOINT_PERIOD = 10;
    uint256 private constant DEFAULT_MIN_VALIDATOR_STAKE = 1 ether;
    uint256 private constant DEFAULT_RELAYER_REWARD = 10 gwei;
    uint64 private constant DEFAULT_MIN_VALIDATORS = 1;
    bytes private constant GENESIS = EMPTY_BYTES;
    uint8 private constant DEFAULT_MAJORITY_PERCENTAGE = 70;
    int8 private constant DEFAULT_POWER_SCALE = 18;
    uint64 private constant ROOTNET_CHAINID = 123;
    uint256 private constant CROSS_MSG_FEE = 10 gwei;

    SubnetRegistryDiamond registry;
    bytes4[] empty;

    DiamondLoupeFacet louper;
    DiamondCutFacet dcFacet;
    RegisterSubnetFacet registerSubnetFacet;
    SubnetGetterFacet private subnetGetterFacet;
    bytes4[] private dcFacetSelectors;
    bytes4[] private louperSelectors;

    bytes4[] private registerSubnetFacetSelectors;
    bytes4[] private subnetGetterFacetSelectors;

    error FacetCannotBeZero();
    error WrongGateway();
    error CannotFindSubnet();
    error UnknownSubnet();
    error GatewayCannotBeZero();

    constructor() {
        louperSelectors = TestUtils.generateSelectors(vm, "DiamondLoupeFacet");
        dcFacetSelectors = TestUtils.generateSelectors(vm, "DiamondCutFacet");
        registerSubnetFacetSelectors = TestUtils.generateSelectors(vm, "RegisterSubnetFacet");
        subnetGetterFacetSelectors = TestUtils.generateSelectors(vm, "SubnetGetterFacet");
    }

    // Event emitted when a new SubnetRegistry is created
    event SubnetRegistryCreated(address indexed subnetRegistryAddress);

    function setUp() public {
        bytes4[] memory mockedSelectors = new bytes4[](1);
        mockedSelectors[0] = 0x6cb2ecee;

        bytes4[] memory mockedSelectors2 = new bytes4[](1);
        mockedSelectors2[0] = 0x133f74ea;

        SubnetRegistryDiamond.ConstructorParams memory params;
        params.gateway = DEFAULT_IPC_GATEWAY_ADDR;
        params.getterFacet = address(new SubnetActorGetterFacet());
        params.managerFacet = address(new SubnetActorManagerFacet());
        params.subnetGetterSelectors = mockedSelectors;
        params.subnetManagerSelectors = mockedSelectors2;

        louper = new DiamondLoupeFacet();
        dcFacet = new DiamondCutFacet();
        registerSubnetFacet = new RegisterSubnetFacet();
        subnetGetterFacet = new SubnetGetterFacet();

        IDiamond.FacetCut[] memory gwDiamondCut = new IDiamond.FacetCut[](4);

        gwDiamondCut[0] = (
            IDiamond.FacetCut({
                facetAddress: address(louper),
                action: IDiamond.FacetCutAction.Add,
                functionSelectors: louperSelectors
            })
        );
        gwDiamondCut[1] = (
            IDiamond.FacetCut({
                facetAddress: address(dcFacet),
                action: IDiamond.FacetCutAction.Add,
                functionSelectors: dcFacetSelectors
            })
        );
        gwDiamondCut[2] = (
            IDiamond.FacetCut({
                facetAddress: address(registerSubnetFacet),
                action: IDiamond.FacetCutAction.Add,
                functionSelectors: registerSubnetFacetSelectors
            })
        );
        gwDiamondCut[3] = (
            IDiamond.FacetCut({
                facetAddress: address(subnetGetterFacet),
                action: IDiamond.FacetCutAction.Add,
                functionSelectors: subnetGetterFacetSelectors
            })
        );

        registry = new SubnetRegistryDiamond(gwDiamondCut, params);
        louper = DiamondLoupeFacet(address(registry));
        dcFacet = DiamondCutFacet(address(registry));
        registerSubnetFacet = RegisterSubnetFacet(address(registry));
        subnetGetterFacet = SubnetGetterFacet(address(registry));
    }

    // Function to create a new SubnetRegistry contract for expectRevert cases
    function createSubnetRegistry(SubnetRegistryDiamond.ConstructorParams memory params) public returns (address) {
        IDiamond.FacetCut[] memory diamondCut = new IDiamond.FacetCut[](4);

        diamondCut[0] = (
            IDiamond.FacetCut({
                facetAddress: address(louper),
                action: IDiamond.FacetCutAction.Add,
                functionSelectors: louperSelectors
            })
        );
        diamondCut[1] = (
            IDiamond.FacetCut({
                facetAddress: address(dcFacet),
                action: IDiamond.FacetCutAction.Add,
                functionSelectors: dcFacetSelectors
            })
        );
        diamondCut[2] = (
            IDiamond.FacetCut({
                facetAddress: address(registerSubnetFacet),
                action: IDiamond.FacetCutAction.Add,
                functionSelectors: registerSubnetFacetSelectors
            })
        );
        diamondCut[3] = (
            IDiamond.FacetCut({
                facetAddress: address(subnetGetterFacet),
                action: IDiamond.FacetCutAction.Add,
                functionSelectors: subnetGetterFacetSelectors
            })
        );

        SubnetRegistryDiamond newSubnetRegistry = new SubnetRegistryDiamond(diamondCut, params);
        emit SubnetRegistryCreated(address(newSubnetRegistry));
        return address(newSubnetRegistry);
    }

    function test_Registry_Deployment_ZeroGetterFacet() public {
        SubnetRegistryDiamond.ConstructorParams memory params;
        params.gateway = DEFAULT_IPC_GATEWAY_ADDR;
        params.getterFacet = address(0);
        params.managerFacet = address(1);
        params.subnetGetterSelectors = empty;
        params.subnetManagerSelectors = empty;

        vm.expectRevert(FacetCannotBeZero.selector);
        createSubnetRegistry(params);
    }

    function test_Registry_Deployment_ZeroManagerFacet() public {
        SubnetRegistryDiamond.ConstructorParams memory params;
        params.gateway = DEFAULT_IPC_GATEWAY_ADDR;
        params.getterFacet = address(1);
        params.managerFacet = address(0);
        params.subnetGetterSelectors = empty;
        params.subnetManagerSelectors = empty;

        vm.expectRevert(FacetCannotBeZero.selector);
        createSubnetRegistry(params);
    }

    function test_Registry_Deployment_ZeroGateway() public {
        SubnetRegistryDiamond.ConstructorParams memory params;
        params.gateway = address(0);
        params.getterFacet = address(1);
        params.managerFacet = address(1);
        params.subnetGetterSelectors = empty;
        params.subnetManagerSelectors = empty;

        vm.expectRevert(GatewayCannotBeZero.selector);
        createSubnetRegistry(params);
    }

    function test_Registry_Deployment_DifferentGateway() public {
        SubnetActorDiamond.ConstructorParams memory params = SubnetActorDiamond.ConstructorParams({
            parentId: SubnetID({root: ROOTNET_CHAINID, route: new address[](0)}),
            ipcGatewayAddr: address(1),
            consensus: ConsensusType.Fendermint,
            minActivationCollateral: DEFAULT_MIN_VALIDATOR_STAKE,
            minValidators: DEFAULT_MIN_VALIDATORS,
            bottomUpCheckPeriod: DEFAULT_CHECKPOINT_PERIOD,
            majorityPercentage: DEFAULT_MAJORITY_PERCENTAGE,
            activeValidatorsLimit: 100,
            powerScale: DEFAULT_POWER_SCALE,
            minCrossMsgFee: CROSS_MSG_FEE
        });
        vm.expectRevert(WrongGateway.selector);
        registerSubnetFacet.newSubnetActor(params);
    }

    function test_Registry_LatestSubnetDeploy_Revert() public {
        vm.startPrank(DEFAULT_SENDER);
        SubnetActorDiamond.ConstructorParams memory params = SubnetActorDiamond.ConstructorParams({
            parentId: SubnetID({root: ROOTNET_CHAINID, route: new address[](0)}),
            ipcGatewayAddr: DEFAULT_IPC_GATEWAY_ADDR,
            consensus: ConsensusType.Fendermint,
            minActivationCollateral: DEFAULT_MIN_VALIDATOR_STAKE,
            minValidators: DEFAULT_MIN_VALIDATORS,
            bottomUpCheckPeriod: DEFAULT_CHECKPOINT_PERIOD,
            majorityPercentage: DEFAULT_MAJORITY_PERCENTAGE,
            activeValidatorsLimit: 100,
            powerScale: DEFAULT_POWER_SCALE,
            minCrossMsgFee: CROSS_MSG_FEE
        });
        registerSubnetFacet.newSubnetActor(params);
        vm.expectRevert(CannotFindSubnet.selector);
        subnetGetterFacet.latestSubnetDeployed(address(0));
    }

    function test_Registry_GetSubnetDeployedByNonce_Revert() public {
        vm.startPrank(DEFAULT_SENDER);
        SubnetActorDiamond.ConstructorParams memory params = SubnetActorDiamond.ConstructorParams({
            parentId: SubnetID({root: ROOTNET_CHAINID, route: new address[](0)}),
            ipcGatewayAddr: DEFAULT_IPC_GATEWAY_ADDR,
            consensus: ConsensusType.Fendermint,
            minActivationCollateral: DEFAULT_MIN_VALIDATOR_STAKE,
            minValidators: DEFAULT_MIN_VALIDATORS,
            bottomUpCheckPeriod: DEFAULT_CHECKPOINT_PERIOD,
            majorityPercentage: DEFAULT_MAJORITY_PERCENTAGE,
            activeValidatorsLimit: 100,
            powerScale: DEFAULT_POWER_SCALE,
            minCrossMsgFee: CROSS_MSG_FEE
        });
        registerSubnetFacet.newSubnetActor(params);
        vm.expectRevert(CannotFindSubnet.selector);
        subnetGetterFacet.getSubnetDeployedByNonce(address(0), 1);
    }

    function test_Registry_Deployment_Works() public {
        _assertDeploySubnetActor(
            DEFAULT_IPC_GATEWAY_ADDR,
            ConsensusType.Fendermint,
            DEFAULT_MIN_VALIDATOR_STAKE,
            DEFAULT_MIN_VALIDATORS,
            DEFAULT_CHECKPOINT_PERIOD,
            DEFAULT_MAJORITY_PERCENTAGE,
            DEFAULT_POWER_SCALE
        );
    }

    function _assertDeploySubnetActor(
        address _ipcGatewayAddr,
        ConsensusType _consensus,
        uint256 _minActivationCollateral,
        uint64 _minValidators,
        uint64 _checkPeriod,
        uint8 _majorityPercentage,
        int8 _powerScale
    ) public {
        vm.startPrank(DEFAULT_SENDER);
        SubnetActorDiamond.ConstructorParams memory params = SubnetActorDiamond.ConstructorParams({
            parentId: SubnetID({root: ROOTNET_CHAINID, route: new address[](0)}),
            ipcGatewayAddr: _ipcGatewayAddr,
            consensus: _consensus,
            minActivationCollateral: _minActivationCollateral,
            minValidators: _minValidators,
            bottomUpCheckPeriod: _checkPeriod,
            majorityPercentage: _majorityPercentage,
            activeValidatorsLimit: 100,
            powerScale: _powerScale,
            minCrossMsgFee: CROSS_MSG_FEE
        });
        registerSubnetFacet.newSubnetActor(params);
        require(subnetGetterFacet.latestSubnetDeployed(DEFAULT_SENDER) != address(0));
        //require(register.s.subnets(DEFAULT_SENDER, 0) != address(0), "fails");
        // require(subnetGetterFacet.getSubnetDeployedByNonce(DEFAULT_SENDER, 0) == registry.latestSubnetDeployed(DEFAULT_SENDER));
    }
}
