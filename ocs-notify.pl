#!/usr/bin/perl

use strict;
use warnings;
use encoding 'utf8';
use DBI;
use Email::Send;
use Email::Simple::Creator;


### Config vars
my $notify_mail = 'fail@smtp';
my $from_mail = 'inventory@smtp';

my $mailer = Email::Send->new( {
	mailer => 'SMTP',
	mailer_args => [ Host => 'localhost' ]
});


### DB references array (Subject, table name, DB select)
my @reports = (
	{subject => "Изменение состава ПО узла", table =>"softwares_changes",
	query =>	"
	SELECT
		sw.ID, 
		hw.NAME AS HOSTNAME,
		DATE(GREATEST(sw.LAST_TS, sw.INSERT_TS)) AS DATE,
		IF (sw.DELETED, 'удалено', 'добавлено') AS STATUS,
		CONCAT (sw.NAME, 
			IF (sw.VERSION, CONCAT(' (', sw.VERSION,')'), ''), 
			IF (sw.FILESIZE, CONCAT(' [', sw.FILESIZE,' КБ]'), '') ) 
			AS NAME
	FROM 
		softwares_changes sw
			INNER JOIN hardware hw
				ON hw.ID = sw.HARDWARE_ID
	WHERE sw.NOTIFIED IS false 
	ORDER BY
		hw.NAME ASC,
		sw.DELETED DESC,
		DATE DESC,
		NAME ASC"},	 #AND h.OSNAME LIKE '%Microsoft%'
	
	{subject => "Изменение комплекиаци дисков узла", table => "storages_changes",
	query => "
	SELECT
		st.ID,
		hw.NAME AS HOSTNAME,
		DATE(GREATEST (st.LAST_TS, st.INSERT_TS)) AS DATE,
		IF (st.DELETED, 'удалён', 'добавлен') AS STATUS,
		CONCAT (
			IF (st.NAME = '' OR st.NAME LIKE '_d_', st.MODEL, st.NAME),
			IF (st.DISKSIZE, CONCAT(' (', ROUND(st.DISKSIZE/1024),' ГБ)'), ''),
			IF (st.SERIALNUMBER, CONCAT(' [№ ', st.SERIALNUMBER,']'), '') 
			) AS NAME
	FROM
		storages_changes st
			INNER JOIN hardware hw
				ON hw.ID = st.HARDWARE_ID
	WHERE st.NOTIFIED IS false
	ORDER BY
		hw.NAME ASC,
		st.DELETED DESC,
		DATE DESC,
		NAME ASC"},

	{subject => "Изменение комплектации контроллеров узла", table => "controllers_changes",
	query => "
	SELECT
		ct.ID,
		hw.NAME AS HOSTNAME,
		DATE(GREATEST (ct.LAST_TS, ct.INSERT_TS)) AS DATE,
		IF (ct.DELETED, 'удалён', 'добавлен') AS STATUS,
		CONCAT (IF (ct.NAME NOT LIKE CONCAT(ct.MANUFACTURER,'%'), CONCAT(ct.MANUFACTURER, ' '), ''), 
			ct.NAME) AS NAME
	FROM
		controllers_changes ct
			INNER JOIN hardware hw
				ON hw.ID = ct.HARDWARE_ID
	WHERE ct.NOTIFIED IS false
	ORDER BY
		hw.NAME ASC,
		ct.DELETED DESC,
		DATE DESC,
		NAME ASC"},
		
	{subject => "Изменение комплектации мониторов узла", table => "monitors_changes",
	query => "
	SELECT
		mn.ID,
		hw.NAME AS HOSTNAME,
		DATE(GREATEST (mn.LAST_TS, mn.INSERT_TS)) AS DATE,
		IF (mn.DELETED, 'удалён', 'добавлен') AS STATUS,
		CONCAT (mn. MANUFACTURER, ' ', mn.CAPTION,
			IF (mn.SERIAL !='', CONCAT(' [№ ', mn.SERIAL,']'), '')
			) AS NAME
	FROM     monitors_changes mn
		INNER JOIN hardware hw
			ON hw.ID = mn.HARDWARE_ID
	WHERE mn.NOTIFIED IS false
	ORDER BY
		hw.NAME ASC,
		mn.DELETED DESC,
		DATE DESC,
		NAME ASC"},

	{subject => "Изменение комплектации оперативной памяти узла", table => "memories_changes",
	query => "
	SELECT
		mc.ID,
		hw.NAME AS HOSTNAME,
		DATE(GREATEST (mc.LAST_TS, mc.INSERT_TS)) AS DATE,
		IF (mc.DELETED, 'удалён', 'добавлен') AS STATUS,
		CONCAT ('Модуль ', mc.NUMSLOTS, ', ', 
			mc.CAPTION, ' (', 
			mc.CAPACITY, ' МБ',
			IF ((mc.SPEED !='' AND mc.SPEED != 'Unknown'), CONCAT (', ',mc.TYPE,'-',mc.SPEED), ''),	')',
			IF ((mc.SERIALNUMBER !='' AND mc.SERIALNUMBER NOT LIKE 'SerNum_'), CONCAT(' [№ ', mc.SERIALNUMBER,']'), '')
			) AS NAME
	FROM memories_changes mc
        INNER JOIN hardware hw
            ON hw.ID = mc.HARDWARE_ID
	WHERE mc.NOTIFIED IS false
	ORDER BY
		hw.NAME ASC,
		mc.DELETED DESC,
		DATE DESC,
		NAME ASC"},

	{subject => "Изменение комплектации процессоров узла", table => "hardware_changes",
	query => "
	SELECT
		hc.ID,
		hw.NAME AS HOSTNAME,
		DATE(GREATEST (hc.LAST_TS, hc.INSERT_TS)) AS DATE,
		IF (hc.DELETED, 'удалён', 'добавлен') AS STATUS,
		hc.PROCESSORT AS NAME
	FROM hardware_changes hc
        INNER JOIN hardware hw
            ON hw.ID = hc.HARDWARE_ID
	WHERE hc.NOTIFIED IS false
	ORDER BY
		hw.NAME ASC,
		hc.DELETED DESC,
		DATE DESC,
		NAME ASC"}
);


### DB Connect
my $dbh = DBI->connect(
	"dbi:mysql:dbname=ocsweb",
	"ocs",
	"dbpass",
	{ RaiseError => 1 },
) or die $DBI::errstr;
$dbh->{"mysql_enable_utf8"} = 1;
$dbh->do("SET NAMES utf8");


### Main flow
foreach (@reports) {
	# Execute DB select query for each @reports to $result as hashref
	my $result = $dbh->selectall_arrayref($_->{query}, { Slice => {} });
	
	# Parse $result to hashref (HOSTNAME, ID) of text messages 
	my %messages;
	my @ids;
	foreach my $row ( @$result ) {
		push @{ $messages{$row->{HOSTNAME}} }, "$row->{DATE} $row->{STATUS} $row->{NAME}\n"; 
		push @ids, $row->{ID}; #row ID for later DB update
	}
	
	#Generate mail messages from text messages for each host
	foreach my $hostname ( keys %messages )  {
		my $subject =  "$_->{subject} $hostname";
		my $body = join("", @{$messages{$hostname}});
		my $email = Email::Simple->create(
			header => [
				From => $from_mail,
				To => $notify_mail,
				Subject => $subject ],
			body => $body );
		$mailer->send($email);
	}
	
	#Mark notified change IDs in DB if IDs exist
	if (@ids) {
		my $notified_ids = join (", ", @ids);
		my $update_query = "UPDATE $_->{table} SET NOTIFIED = true WHERE ID in ($notified_ids)";
		$dbh->do($update_query);
	};

};


### DB Close
$dbh->disconnect();
