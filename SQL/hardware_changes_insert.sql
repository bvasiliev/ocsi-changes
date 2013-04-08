DELIMITER $$

DROP TRIGGER IF EXISTS `hardware_changes_insert` $$

CREATE TRIGGER `hardware_changes_insert` AFTER INSERT ON `hardware` 
FOR EACH ROW BEGIN
		INSERT INTO `hardware_changes` (HARDWARE_ID, PROCESSORT, PROCESSORN, UUID)
            SELECT NEW.ID, NEW.PROCESSORT, NEW.PROCESSORN, NEW.UUID
            FROM dual WHERE (NEW.PROCESSORT IS NOT NULL)
			ON DUPLICATE KEY UPDATE
				HARDWARE_ID=NEW.ID,
				DELETED=FALSE;
END$$

DELIMITER ;
