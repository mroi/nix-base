{ ... }: {

	config.system.cleanupScripts.files = ''
		storeHeading -

		{
			echo 'BEGIN IMMEDIATE TRANSACTION;'
			echo 'CREATE TABLE files (path TEXT PRIMARY KEY);'
			echo "INSERT INTO files (path) VALUES ('test');"
			echo 'COMMIT TRANSACTION;'
		} | runSQL
		{
			echo "SELECT 'Hello SQLite';"
		} | runSQL
		{
			echo 'SELECT * FROM files;'
		} | runSQL
	'';
}
