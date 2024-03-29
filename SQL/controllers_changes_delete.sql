DELIMITER $$

DROP TRIGGER IF EXISTS `controllers_changes_delete` $$

CREATE TRIGGER `controllers_changes_delete` AFTER DELETE ON `controllers` 
FOR EACH ROW BEGIN
		UPDATE `controllers_changes` 
			SET
				DELETED=TRUE,
				NOTIFIED=FALSE,
				LAST_TS=CURRENT_TIMESTAMP
			WHERE 
				CONTROLLER_ID=OLD.ID
				AND HARDWARE_ID=OLD.HARDWARE_ID
				AND	MANUFACTURER=OLD.MANUFACTURER
				AND	NAME=OLD.NAME;

END$$

DELIMITER ;
