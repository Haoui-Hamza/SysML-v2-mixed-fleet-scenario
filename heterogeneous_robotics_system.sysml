package MixedFleet {
    private import ScalarValues::*;
    // Base vehicle definition

    requirement def <'1'> ScanWarehouseRequirement{
        private import ISQ::*;
        private import SI::*;
	    private import NumericalFunctions::*;
        doc /* The drone must scan the warehouse for an empty rack. */
    
        subject drone : Drone;
    
        attribute scanRange : LengthValue = drone.scanRange;
    
    
        assume constraint {
            drone.scanRange > 3[m] // Ensure the drone has a valid scanning range 
        }
    }
    
    part def Vehicle {
        attribute id : String;
        attribute position : Coordinate;
        attribute autonomyLevel: Real;
        port platformMessage : MessagePort;
    }

    // Automated Guided Vehicle (AGV/UGV)
    part def UGV specializes Vehicle {
        attribute maxLoad : ISQ::MassValue[*];
        action movePallet : MovePallet;
    }
    // Drone with scanning capabilities
    part def Drone specializes Vehicle {
        attribute scanRange : ISQ::LengthValue[*];
        port sensorsData : MessagePort;

        action scanWarehouse : ScanWarehouse;
    }

    // Autonomous Forklift
    part def Forklift specializes Vehicle {
        attribute liftingCapacity : ISQ::MassValue;
        attribute forkHeight : ISQ::LengthValue[*];

        action confirmPickup : ConfirmPickup;
        action placePallet : PlacePallet;
    }
    

    ////////// START actions definition //////////

        // Action for Drone scanning the warehouse for an empty rack
        action def ScanWarehouse {
            in vehicle: Vehicle;
            out emptyRackLocation: Coordinate;
        }

        // Action for AGV moving the pallet to the collection point
        action def MovePallet {
            in ugv: UGV;
            in palletLocation: Coordinate;
            in destination: Coordinate;
            out completed: Boolean;
            out timeoutOccurred: Boolean;
        }

        // Action for Forklift confirming it has picked up the pallet
        action def ConfirmPickup {
            in vehicle: Vehicle; 
            in palletLocation: Coordinate;
            out pickupConfirmed: Boolean;
        }

        // Action for Forklift placing the pallet on the free rack
        action def PlacePallet {
            in forklift: Forklift;
            in rackLocation: Coordinate;
            out completed: Boolean;
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
            then action movePallet : MovePallet {
                in ugv: moveItemMission.ugv;
                in palletLocation = moveItemMission.palletLocation;
                in destination = scanWarehouse.emptyRackLocation;
                out completed;
            }
            // Decision: If movePallet fails, reassign task
            then decide;
            if movePallet.timeoutOccurred then reassignMove;
            else confirmPickup;
            // Forklift confirms pickup
            then action confirmPickup: ConfirmPickup{
                in vehicle: moveItemMission.forklift; 
                in palletLocation = moveItemMission.palletLocation;
                out pickupConfirmed;
            } 
            // Decision: If the pickup is **not confirmed**, reattempt scanning
            then decide;
            if confirmPickup.pickupConfirmed then placePallet;
			else restartScan;
            // Forklift places the pallet
            action placePallet:PlacePallet{
                in rackLocation: scanWarehouse.emptyRackLocation;
                out completed;
                out timeoutOccurred;
            }
            // Decision: If placement **fails**, reassign or restart scan process
            then decide;
            if placePallet.timeoutOccurred == true then reassignPlace;
            //if placePallet.completed == true then reassignPlace ;
            else restartScan;

            // Task reassignment logic
            action reassignMove : MovePallet {
                in ugv: UGV;
                in palletLocation = moveItemMission.palletLocation;
                in destination = scanWarehouse.emptyRackLocation;
                out completed;
            }

            action reassignPlace : PlacePallet {
                in forklift: Forklift;
                in rackLocation: scanWarehouse.emptyRackLocation;
                out completed;
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