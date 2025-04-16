package MixedFleet {
    private import ScalarValues::*;
    // Base vehicle definition

    requirement ScanWarehouseRequirement{
        private import ISQ::*;
        private import SI::*;
	    private import NumericalFunctions::*;
        doc /* The drone must scan the warehouse for an empty rack. */
    
        subject drone : Drone;
    
        attribute scanRange :> ISQ::length ;
    
        require constraint {
            drone.scanRange > 3[m] // Ensure the drone has a valid scanning range 
        }
    }

    verification def ScanWarehouseTest{
        private import VerificationCases::*;
        subject testDrone : Drone;
        objective scanWarehouseVerificationObjective {
            verify ScanWarehouseRequirement ;
        }
        action collectData {
            in part testDrone : Drone = ScanWarehouseTest::testDrone;
            out effectiveScanRangeMeasured :> ISQ::length;
        }
        action processData {
            in scanRangeMeasured :> ISQ::length = collectData.effectiveScanRangeMeasured;
            out scanRangeProcessed :> ISQ::length;
        }

        action evaluateData {
            in scanRangeProcessed :> ISQ::length = processData.scanRangeProcessed;
            out verdict : VerdictKind =
            PassIf(ScanWarehouseRequirement(
                drone = testDrone,
                scanRange = scanRangeProcessed
            ));
        }
        return verdict : VerdictKind = evaluateData.verdict;
    }
    
    part def Vehicle {
        attribute id : String;
        attribute position : Coordinate;
        attribute autonomyLevel: Real;
        port platformMessage : MessagePort;
        port sensorsData : MessagePort;
    }

    // Automated Guided Vehicle (AGV/UGV)
    part def UGV specializes Vehicle {
        attribute maxLoad : ISQ::MassValue[*];
        action movePallet : MoveObject;
    }
    // Drone with scanning capabilities
    part def Drone specializes Vehicle {
        attribute scanRange : ISQ::LengthValue[*];

        action scanWarehouse : ScanWarehouse;
    }

    // Autonomous Forklift
    part def Forklift specializes Vehicle {
        attribute liftingCapacity : ISQ::MassValue;
        attribute forkHeight : ISQ::LengthValue[*];

        action placePallet : PlacePallet;
        action pickupPallet : MoveObject;
    }
    

    ////////// START actions definition //////////

        // Action for Drone scanning the warehouse for an empty rack
        action def ScanWarehouse {
            in vehicle: Vehicle;
            out emptyRackLocation: Coordinate;
        }

        // Action for AGV moving the pallet to the collection point
        action def MoveObject {
            in vehicle: Vehicle;
            in source: Coordinate;
            in destination: Coordinate;
            out completed: Boolean;
            out placedLocation:Boolean;
            out timeoutOccurred: Boolean;
        }

        action def ReassignVehicle{
            //in availableVehicles: Vehicle[0..*];
            out vehicle: Vehicle;
        }

        // Action for Forklift confirming it has picked up the pallet
        action def PlacePallet {
            in forklift: Forklift; 
            in RackLocation: Coordinate;
            out pickupConfirmed: Boolean;
        }

        action def MovingItemMission {
            in ugv:UGV;
            in drone:Drone;
            in forklift:Forklift;
            in palletLocation: Coordinate;
            out completed: Boolean;
        }

        action moveItemMission : MovingItemMission {
            in ugv:UGV;
            in drone:Drone;
            in forklift:Forklift;
            in palletLocation: Coordinate;
            

            first start;

            then merge restartScan;
            // Drone scans for an empty rack        
            then loop action scanWarehouse : ScanWarehouse{
                in vehicle = moveItemMission.drone;
                out emptyRackLocation;
            } 
            // UGV moves the pallet to the collection point
            then action movePallet : MoveObject {
                in ugv: moveItemMission.ugv;
                in source = moveItemMission.palletLocation;
                in destination = scanWarehouse.emptyRackLocation;
                out timeoutOccurred;
                out placedLocation;
                out completed;
            }
            // Decision: If movePallet fails, reassign task
            then decide;
            if movePallet.timeoutOccurred then reassignVehicle;
            else pickupPallet;
            // Forklift confirms pickup
            then action pickupPallet: MoveObject{
                in vehicle: moveItemMission.forklift; 
                in palletLocation = moveItemMission.palletLocation;
                in destination: movePallet.placedLocation;
                out completed: Boolean;
                out timeoutOccurred: Boolean;
            } 
            // Decision: If the pickup is **not confirmed**, reattempt scanning
            then decide;
            if pickupPallet.completed then placePallet;
			else restartScan;
            // Forklift places the pallet
            action placePallet:PlacePallet{
                in rackLocation: scanWarehouse.emptyRackLocation;
                out completed;
                out timeoutOccurred;
            }
            // Decision: If placement **fails**, reassign or restart scan process
            then decide;
            if placePallet.timeoutOccurred == true then reassignVehicle;
            //if placePallet.completed == true then reassignPlace ;
            else restartScan;

            action reassignVehicle : ReassignVehicle {
                out vehicle:Vehicle;
            }

        }
        

    ////////// END actions definition //////////


    // Data types definitions
    attribute def Coordinate {
        attribute X : Real ;
        attribute Y : Real ;
        attribute Z : Real ;
    }

    part def MxfMessage {
        attribute command : String;
        attribute file : String ;
    }
    // Ports definition
    port def MessagePort {
        in item request : MxfMessage;
        out item  response : MxfMessage;
    }

    

}
