DELIMITER $$

DROP TRIGGER IF EXISTS `controllers_changes_insert` $$

CREATE TRIGGER `controllers_changes_insert` AFTER INSERT ON `controllers` 
FOR EACH ROW BEGIN
		INSERT INTO `controllers_changes` (CONTROLLER_ID, HARDWARE_ID, MANUFACTURER, NAME, TYPE)
            SELECT NEW.ID, NEW.HARDWARE_ID, NEW.MANUFACTURER, NEW.NAME, NEW.TYPE
            FROM dual WHERE (NEW.MANUFACTURER NOT LIKE '%стандарт%' AND  NEW.MANUFACTURER NOT LIKE '%standart%')
			ON DUPLICATE KEY UPDATE
				CONTROLLER_ID=NEW.ID,
				DELETED=FALSE;
END$$

DELIMITER ;

