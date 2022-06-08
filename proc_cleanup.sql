DELETE FROM MktObjBlob;
INSERT INTO MktObjBlob SELECT * FROM MktObjBlob_bak;
DELETE FROM MktObjSnap;
INSERT INTO MktObjSnap SELECT * FROM MktObjSnap_bak;
CREATE OR REPLACE TABLE tracker (BlobID INT);
DROP PROCEDURE IF EXISTS cleanup;


DELIMITER //
CREATE PROCEDURE cleanup ()
BEGIN

	DECLARE t0 INT;
	DECLARE t1 INT;
	DECLARE tmax INT;
	DECLARE row_deleted INT DEFAULT 10;
	DELETE FROM tracker;
    SET t0 = (select min(BlobId) from MktObjBlob);
    SET tmax = (select max(BlobID) from MktObjBlob);
	SET row_deleted = 3;
	
    -- DECLARE `should_rollback` BOOL DEFAULT FALSE;
	-- DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET `should_rollback` = TRUE;
    
    WHILE t0 <= (tmax-row_deleted)
    do
        SET t1 = t0+row_deleted;
		SELECT CONCAT("Checking"," ",t0," to ",t1);
		
		START TRANSACTION;
        INSERT INTO tracker SELECT BlobID FROM MktObjBlob WHERE BlobID >= t0 AND BlobID <=t1 RETURNING BlobID;
		
		SELECT BlobID FROM MktObjBlob 
		WHERE BlobID >= t0 AND BlobID <= t1 
		AND BlobID NOT IN (SELECT BlobID FROM MktObjSnap WHERE BlobID >= t0 AND BlobID <= t1); -- Does it work?
		
		DELETE FROM MktObjBlob 
		WHERE BlobID >= t0 AND BlobID <= t1 
		AND BlobID NOT IN (SELECT BlobID FROM MktObjSnap WHERE BlobID >= t0 AND BlobID <= t1);

	--	IF `should_rollback` THEN
	--		ROLLBACK;
	--	ELSE
	--		COMMIT;
	--	END IF;
        COMMIT;

        SET t0 = t1+1;
    END WHILE;
END //
DELIMITER ;
CALL cleanup;
