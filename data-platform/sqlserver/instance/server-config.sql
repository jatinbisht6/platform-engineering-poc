-- Enable advanced options
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;

-- Core configurations
EXEC sp_configure 'allow polybase export', 0;
RECONFIGURE;

EXEC sp_configure 'allow updates', 0;
RECONFIGURE;

EXEC sp_configure 'backup checksum default', 0;
RECONFIGURE;

EXEC sp_configure 'backup compression algorithm', 0;
RECONFIGURE;

EXEC sp_configure 'backup compression default', 0;
RECONFIGURE;

EXEC sp_configure 'clr enabled', 0;
RECONFIGURE;

EXEC sp_configure 'column encryption enclave type', 0;
RECONFIGURE;

EXEC sp_configure 'contained database authentication', 0;
RECONFIGURE;

EXEC sp_configure 'cross db ownership chaining', 0;
RECONFIGURE;

EXEC sp_configure 'default language', 0;
RECONFIGURE;

EXEC sp_configure 'external scripts enabled', 0;
RECONFIGURE;

EXEC sp_configure 'filestream access level', 0;
RECONFIGURE;

EXEC sp_configure 'hadoop connectivity', 0;
RECONFIGURE;

EXEC sp_configure 'max text repl size (B)', 65536;
RECONFIGURE;

EXEC sp_configure 'nested triggers', 1;
RECONFIGURE;

EXEC sp_configure 'polybase enabled', 0;
RECONFIGURE;

EXEC sp_configure 'polybase network encryption', 1;
RECONFIGURE;

EXEC sp_configure 'remote access', 1;
RECONFIGURE;

EXEC sp_configure 'remote admin connections', 0;
RECONFIGURE;

EXEC sp_configure 'remote data archive', 0;
RECONFIGURE;

EXEC sp_configure 'remote login timeout (s)', 10;
RECONFIGURE;

EXEC sp_configure 'remote proc trans', 0;
RECONFIGURE;

EXEC sp_configure 'remote query timeout (s)', 600;
RECONFIGURE;

EXEC sp_configure 'server trigger recursion', 1;
RECONFIGURE;

EXEC sp_configure 'user options', 0;
RECONFIGURE;