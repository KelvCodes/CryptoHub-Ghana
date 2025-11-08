

contract DeployRevert {
	constructor() public {
		require(false);
	}
}
