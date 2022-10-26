--=================================READ ME============================================
-- ===================================================================================
-- Author:		Ruben Lopez
-- Create date: 2021-04-30
-- Modified date: 2022-10-15
-- Description:	Base script to create temporary functions and get a test class 
--				using tSQLt framework. 
--				This is a tool to easily build a new tSQLt Test Class that will include 
--				the arrange section user defined functions, user defined stored procedures 
--				and tables which the object to be tested depends. It also will let you fake 
--				those tables with actuall data taken from you development database to 
--				populate fake tables.
-- ===================================================================================

--[TODO: Manually set database name if is not set by replacing <DATABASE_NAME>]
--USE <DATABASE_NAME>
--GO

IF object_id(N'dbo.fnGetTableFromCSVString', N'TF') IS NOT NULL
    DROP FUNCTION dbo.fnGetTableFromCSVString
GO

-- ====================================================
-- Author:		Ruben Lopez
-- Create date: 2021-04-30
-- Description:	Returns a table from a given CSV string
-- ====================================================
CREATE FUNCTION dbo.fnGetTableFromCSVString
(
		@csvStringToSplit nvarchar(max)
)
RETURNS 
	@csvItems TABLE
	(
		Item varchar(100)
	)
BEGIN
	DECLARE @item nvarchar(100), @index int;
	WHILE CHARINDEX(',',@csvStringToSplit) > 0
		BEGIN
			SET @index = CHARINDEX(',',@csvStringToSplit)
			SET @item = LTRIM(RTRIM(SUBSTRING(@csvStringToSplit,1,@index - 1)))

			INSERT INTO @csvItems (Item) VALUES (@item)

			SELECT @csvStringToSplit = SUBSTRING(@csvStringToSplit, @index+1,LEN(@csvStringToSplit)-@index)
		END

	INSERT INTO @csvItems (Item) VALUES (@csvStringToSplit)
	RETURN
END
GO

IF object_id(N'dbo.fnGetColumnsCorrectFormatForQuery', N'FN') IS NOT NULL
    DROP FUNCTION dbo.fnGetColumnsCorrectFormatForQuery
GO

-- ===================================================================================
-- Author:		Ruben Lopez
-- Create date: 2021-04-30
-- Description:	Returns column's name in the format used at TestClassHelper script to
--				building the query that retrieves data to populate fake tables
-- ===================================================================================
CREATE FUNCTION dbo.fnGetColumnsCorrectFormatForQuery
(
		@columnName varchar(100), 
		@tableName varchar(100)
)
RETURNS VARCHAR(150)
AS
BEGIN
	DECLARE @dataType varchar(50), 
			@needsConvertion bit = 0,
			@needsAphostrophee bit,
			@numericOrBool bit,
			@formattedColumnForQuery varchar(150) = ''
	
	SET @dataType = (SELECT DATA_TYPE 
					FROM INFORMATION_SCHEMA.COLUMNS
					WHERE 
						 TABLE_NAME = @tableName AND 
						 COLUMN_NAME = ltrim(rtrim(@columnName)))

	set @needsAphostrophee = (SELECT CASE WHEN
								@dataType in ('char',
											'text',
											'nchar',
											'ntext',
											'varchar',
											'nvarchar') THEN 1
								ELSE 0 END)

	SET @needsConvertion = (SELECT CASE WHEN
								@dataType in ('date',
											'datetime',
											'datetime2',
											'datetimeoffset',
											'smalldatetime',
											'time',
											'binary',
											'varbinary',
											'image',
											'blob') THEN 1
								ELSE 0 END)

	SET @numericOrBool = (SELECT CASE WHEN
								@dataType in ('bigint',
											'numeric',
											'bit',
											'smallint',
											'decimal',
											'smallmoney',
											'int',
											'tinyint',
											'money',
											'float',
											'real') THEN 1
								ELSE 0 END)


	IF @needsAphostrophee = 1
		SET @formattedColumnForQuery = ' COALESCE(QUOTENAME('+@columnName+', ''"''), ''NULL'') '
	ELSE IF @needsConvertion = 1
		SET @formattedColumnForQuery = ' COALESCE(CONVERT(VARCHAR, QUOTENAME('+ @columnName +',''"'') ,0), ''NULL'') '
	ELSE IF @numericOrBool = 1
		SET @formattedColumnForQuery = ' COALESCE(CONVERT(VARCHAR,'+@columnName+'), ''NULL'') '
	ELSE
		SET @formattedColumnForQuery = ' COALESCE(' + @columnName + ',''NULL'') '

	RETURN @formattedColumnForQuery
END
GO


-- ===================================================================================
-- Author:		Ruben Lopez
-- Create date: 2021-04-30
-- Description:	Returns column's name in the format used at TestClassHelper script to
--				building the query that retrieves data to populate fake tables
-- ===================================================================================

--[TODO: Set @OcjectToWriteTest as the stored procedure/function name you like to get the test class
DECLARE @ObjectToWriteTest VARCHAR(250) = ''

DECLARE @filteredQueries TABLE
(
	SchemaName VARCHAR(100) default 'dbo',
	TableName VARCHAR(100) not null,
	Filtered BIT not null,
	FilterWithValues NVARCHAR(max),
	SpecificColumnList VARCHAR(max),
	FullTableName AS CONCAT(SchemaName, '.', TableName)
)

--[TODO: Uncomment this if you are willing to use filtered queries]
--INSERT INTO @filteredQueries(SchemaName, TableName, Filtered, FilterWithValues, SpecificColumnList) VALUES
--('<SchemaName>, <TableName>, <Filtered>, <FilterWithValues>, <SpecificColumnList>),

BEGIN
	SET NOCOUNT ON;

	DECLARE @testSchemaName VARCHAR(150) = '',
	@scriptToBePrintedOut NVARCHAR(max) = '',
	@fullTableName VARCHAR(max) = '',
	@tableName VARCHAR(100) = '',
	@schemaName VARCHAR(50) = '',
	@coulumnList VARCHAR(max) = '',
	@scriptToExecute NVARCHAR(max) = '',
	@lastColumnID INT = 0,
	@queryToExecuteOnTable NVARCHAR(max) = '',
	@queryColumns NVARCHAR(max) = '',
	@filtered BIT = 0,
	@filters NVARCHAR(max) = '',
	@filteredQueryResult NVARCHAR(max) = '',
	@specificColumnList NVARCHAR(max) = '',
	@lastQueryFilteredResultID INT = 0,
	@functionName VARCHAR(max) = '',
	@ErrorMessage VARCHAR(max) = ''

	set @testSchemaName = @ObjectToWriteTest + 'Tests'

	-----------------------------------------------------------------
	---------------------1. TEMPORARY TABLES-------------------------
	-----------------------------------------------------------------

	--Temporary table for get all object dependencies from sp_depends
	DECLARE @ObjectDependencies TABLE
	(
		ObjectName VARCHAR(250),
		ObjectType VARCHAR(50),
		ObjectUpdate VARCHAR(3),
		ObjectSelected VARCHAR(3),
		ObjectColumn VARCHAR(250)
	)

	--Temporary table for get all object dependencies
	DECLARE @AssociatedObjects TABLE
	(
		AssociatedObjectName VARCHAR(250),
		AssociatedObjectType VARCHAR(50),
		AssociatedObjectColumnName VARCHAR(50)
	)

	--Temporary table for get all functions
	DECLARE @AssociatedFunctions TABLE
	(
		Full_Function_Name VARCHAR(100)
	)

	--Temporary table for get all stored procedures
	DECLARE @AssociatedStoredProcedures TABLE
	(
		Full_StoredProcedure_Name VARCHAR(100)
	)

	--Temporary table for get all views
	DECLARE @AssociatedViews TABLE
	(
		Full_View_Name VARCHAR(250)
	)

	--Temporary table for get all unknown objects
	DECLARE @AssociatedUnknownObjects TABLE
	(
		Full_UnknowObject_Name VARCHAR(100)
	)

	--Temporary table for get all tables
	DECLARE @AssociatedTables TABLE
	(
		Full_Table_Name VARCHAR(250),
		SchemaName VARCHAR(250),
		TableName VARCHAR(250)
	)

	--Temporary table for table's information
	DECLARE @TableInfo TABLE
	(
		ColumnName VARCHAR(100),
		ColumnType VARCHAR(50),
		IsComputed VARCHAR(3),
		ColumnLength INT,
		ColumnPrec VARCHAR(10),
		ColumnScale VARCHAR(3),
		IsNullable VARCHAR(3),
		ColumnTrimTrailingBlanks VARCHAR(10),
		ColumnFixedLenNulInSource  VARCHAR(10),
		ColumnCollation VARCHAR(50)
	)

	DECLARE @ColumnsUsed TABLE
	(
		ObjectName VARCHAR(250),
		ColumnName VARCHAR(250),
		ObjectType VARCHAR(50)
	)

	--Temporary table for getting columns list
	DECLARE @Columns TABLE
	(
		ColumnID INT IDENTITY,
		ColumnName VARCHAR(50)
	)

	--Temporary table for store filtered queries results
	DECLARE @filteredQueriesResults TABLE
	(
		FilteredQueryResultID INT NOT NULL IDENTITY,
		FilteredQueryResult NVARCHAR(max),
		CSVToInsert as '('+FilteredQueryResult+')'
	)


	------------------------------------------------------------------------------------
	-----------------CHECK FEW THINGS BEFORE STARTING BUILDING THE OUTPUT---------------
	------------------------------------------------------------------------------------

	--Check for tSQLt Framework
	IF NOT EXISTS(SELECT * FROM sys.schemas WHERE NAME = 'tSQLt')
		BEGIN
	 		SET @ErrorMessage = ''
				SET @ErrorMessage = 'tSQLt Framework not found, proceed to download and install it from tsqlt.org'
				RAISERROR(@ErrorMessage, 11, 1)
		END

	-----------------------------------------------------------------
	-----------------1. POPULATION OF TEMPORARY TABLES---------------
	-----------------------------------------------------------------

	--Populate @TemporaryAssociatedObjects
	INSERT INTO @ObjectDependencies(ObjectName, ObjectType, ObjectUpdate, ObjectSelected, ObjectColumn)
	EXEC sp_depends @ObjectToWriteTest

	--Populate @AssociatedObjects without duplicates
	INSERT INTO @AssociatedObjects(AssociatedObjectName, AssociatedObjectType, AssociatedObjectColumnName)
	SELECT ObjectName, ObjectType, ObjectColumn 
	FROM @ObjectDependencies
	GROUP BY ObjectName, ObjectType, ObjectColumn

	--Populate @AssociatedTables
	INSERT INTO @AssociatedTables(Full_Table_Name)
	SELECT AssociatedObjectName FROM @AssociatedObjects WHERE AssociatedObjectType like '%USER_TABLE%'
	GROUP BY AssociatedObjectName

	UPDATE T SET T.SchemaName = IST.TABLE_SCHEMA,
			T.TableName = IST.TABLE_NAME
	FROM @AssociatedTables T 
		INNER JOIN INFORMATION_SCHEMA.TABLES IST ON IST.TABLE_CATALOG = DB_NAME()
	WHERE CONCAT(TABLE_SCHEMA, '.', TABLE_NAME) = T.Full_Table_Name

	--Populate @AssociatedFunctions
	INSERT INTO @AssociatedFunctions(Full_Function_Name)
	SELECT AssociatedObjectName FROM @AssociatedObjects WHERE AssociatedObjectType LIKE '%FUNCTION%'
	GROUP BY AssociatedObjectName

	--Populate @AssociatedStoredProcedures
	INSERT INTO @AssociatedStoredProcedures(Full_StoredProcedure_Name)
	SELECT AssociatedObjectName FROM @AssociatedObjects WHERE AssociatedObjectType LIKE '%STORED_PROCEDURE%'
	GROUP BY AssociatedObjectName

	--Populate @AssociatedViews
	INSERT INTO @AssociatedViews(Full_View_Name)
	SELECT AssociatedObjectName FROM @AssociatedObjects WHERE AssociatedObjectType LIKE '%VIEW%'
	GROUP BY AssociatedObjectName

	--Populate @AssociatedUnknownObjects
	INSERT INTO @AssociatedUnknownObjects(Full_UnknowObject_Name)
	SELECT AssociatedObjectName FROM @AssociatedObjects WHERE AssociatedObjectType IS NULL
	GROUP BY AssociatedObjectName

	--Populate @ColumnsUsed
	INSERT INTO @ColumnsUsed(ObjectName, ColumnName, ObjectType)
	SELECT AssociatedObjectName, AssociatedObjectColumnName, AssociatedObjectType
	FROM @AssociatedObjects
	WHERE AssociatedObjectType LIKE '%TABLE%' OR AssociatedObjectType LIKE '%VIEW%'
	GROUP BY AssociatedObjectName, AssociatedObjectColumnName, AssociatedObjectType


	------------------------------------------------------------------
	--------------2. BUILDING THE SCRIPT TO BE PRINTED----------------
	------------------------------------------------------------------
	set @scriptToBePrintedOut = ''
	/*2.1 Build the tests's script schema name*/
	set @scriptToBePrintedOut = 'USE ['+DB_NAME()+']' + CHAR(13) +'GO' + CHAR(10)+CHAR(13)
	set @scriptToBePrintedOut = @scriptToBePrintedOut + 'EXEC ['+DB_NAME()+'].[tSQLt].NewTestClass ''' + @testSchemaName +''''+ CHAR(13) +  CHAR(10) +'GO'+ CHAR(13) +  CHAR(10)+ CHAR(13) +  CHAR(10)

	print @scriptToBePrintedOut

	/*2.2 Build Function's Arrange Section*/
	print ('---------------------------------------------------------------')
	print ('-------------------FAKE FUNCTIONS SECTION----------------------')
	print ('---------------------------------------------------------------')
	PRINT( '--[TODO: Fake your functions here]'+ CHAR(13)+CHAR(10)+ CHAR(13)+CHAR(10))
	set @scriptToBePrintedOut = ''
	IF EXISTS(SELECT * FROM @AssociatedFunctions)
		BEGIN
			DECLARE CURSOR_ASSOCIATED_FUNCTIONS CURSOR FOR SELECT Full_Function_Name FROM @AssociatedFunctions
						OPEN CURSOR_ASSOCIATED_FUNCTIONS
							FETCH NEXT FROM CURSOR_ASSOCIATED_FUNCTIONS INTO @functionName
								WHILE @@FETCH_STATUS = 0
									BEGIN
										SET @scriptToBePrintedOut = ''
										SET @scriptToBePrintedOut = '/*'+@functionName +'*/' +CHAR(10)+
												'--CREATE FUNCTION '+ @testSchemaName + '.'+ replace(@functionName,'dbo.','')+'_Test (@variable1 <dataType1>, @variable2 <dataType2>)' +CHAR(10)+
												'--RETURNS <returnDataType>'+CHAR(10)+
												'--AS'+CHAR(10)+'--BEGIN'+CHAR(10)+'	--[TODO: Write your fake function''s code here]'+CHAR(13)+CHAR(10)+'--END'+CHAR(10)+
												'--GO'+CHAR(10)+CHAR(13)
										print @scriptToBePrintedOut
										FETCH NEXT FROM CURSOR_ASSOCIATED_FUNCTIONS INTO @functionName
									END
							CLOSE CURSOR_ASSOCIATED_FUNCTIONS
						DEALLOCATE CURSOR_ASSOCIATED_FUNCTIONS
		END

	PRINT(CHAR(13)+CHAR(10))

	/*2.3 Build SetUp procedure*/
	print ('---------------------------------------------------------------')
	print ('-----------------------ARRANGE SECTION-------------------------')
	print ('---------------------------------------------------------------')
	set @scriptToBePrintedOut = ''
	set @scriptToBePrintedOut = 'CREATE PROCEDURE ' + @testSchemaName +'.SetUp' + CHAR(10)
	set @scriptToBePrintedOut = @scriptToBePrintedOut + 'AS' + CHAR(10) +'BEGIN'+ CHAR(10)
	print @scriptToBePrintedOut

	print ('	/*	[TODO: Customize your fake tables process by doing the following]
					1. Changing the value of the variables sent to each tSQLt.FakeTable stored procedure in order to meet your needs. 
					2. If you do not need any data to be populated in a fake table, just remove the INSERT INTO statement from the table you need
		*/' +CHAR(10))

	IF EXISTS(SELECT * FROM @AssociatedViews)
		BEGIN
			set @scriptToBePrintedOut = ''
			set @scriptToBePrintedOut = '	/*Arrange Views*/' + CHAR(13) + CHAR(10)
			set @scriptToBePrintedOut = @scriptToBePrintedOut + '	DECLARE @sqlCommand NVARCHAR(MAX) = ''''' + CHAR(13)+CHAR(10) 
			select @scriptToBePrintedOut = @scriptToBePrintedOut + CHAR(13)+CHAR(10) + 
			'	EXEC tSQLt.SetFakeViewOn ' + QUOTENAME(Full_View_Name,'''') from @AssociatedViews
		
			set @scriptToBePrintedOut = @scriptToBePrintedOut + CHAR(13)+CHAR(10)+ CHAR(13)+CHAR(10)+CHAR(13)+CHAR(10)+ CHAR(13)+CHAR(10)
			print @scriptToBePrintedOut
		END

	IF EXISTS(SELECT * FROM @AssociatedFunctions)
		BEGIN
			set @scriptToBePrintedOut = ''
			set @scriptToBePrintedOut = '	/*Arrange Functions*/'
			select @scriptToBePrintedOut = @scriptToBePrintedOut + CHAR(13)+CHAR(10)+
			'	EXEC tSQLt.FakeFunction ' + QUOTENAME(Full_Function_Name,'''') +', ' + 
			QUOTENAME(@testSchemaName+'.'+replace(Full_Function_Name,'dbo.','')+'_Test','''')  from @AssociatedFunctions
		
			set @scriptToBePrintedOut = @scriptToBePrintedOut + CHAR(13)+CHAR(10)+ CHAR(13)+CHAR(10)+CHAR(13)+CHAR(10)+ CHAR(13)+CHAR(10)
			print @scriptToBePrintedOut
		END

	IF EXISTS(SELECT * FROM @AssociatedStoredProcedures)
		BEGIN
			set @scriptToBePrintedOut = ''
			set @scriptToBePrintedOut = '	/*Arrange Stored Procedures*/'
			select @scriptToBePrintedOut = @scriptToBePrintedOut + CHAR(13)+CHAR(10)+
			'	EXEC tSQLt.SpyProcedure  @ProcedureName = ' + QUOTENAME(Full_StoredProcedure_Name,'''') + ', @CommandToExecute = ''''' from @AssociatedStoredProcedures
		
			set @scriptToBePrintedOut = @scriptToBePrintedOut + CHAR(13)+CHAR(10)+ CHAR(13)+CHAR(10)+CHAR(13)+CHAR(10)+ CHAR(13)+CHAR(10)
			print @scriptToBePrintedOut
		END

	/*2.4 Build SetUp procedure*/
	declare CURSOR_ASSOCIATED_TABLES cursor for select Full_Table_Name, SchemaName, TableName from @AssociatedTables
		open CURSOR_ASSOCIATED_TABLES
			fetch next from CURSOR_ASSOCIATED_TABLES into  @fullTableName, @schemaName, @tableName
				while @@FETCH_STATUS = 0
					begin
						--Empty variables
						set @scriptToExecute = ''
						delete from @TableInfo
						delete from @Columns
						delete from @filteredQueriesResults
						set @lastColumnID = 0
						set @scriptToBePrintedOut = ''
						set @queryToExecuteOnTable = ''
						set @filtered = 0
						set @filters = ''
						set @queryColumns = ''
						set @filtered = ''
						set @filters = ''
						set @queryToExecuteOnTable = ''
						set @filteredQueryResult = ''
						set @lastQueryFilteredResultID = 0


						set @scriptToExecute = 'exec sp_help ''' + @fullTableName + ''''

						INSERT INTO @TableInfo(ColumnName, ColumnType, IsComputed, ColumnLength, ColumnPrec, ColumnScale, IsNullable,
						ColumnTrimTrailingBlanks, ColumnFixedLenNulInSource, ColumnCollation)
						exec tsqlt.ResultSetFilter 2, @scriptToExecute

						IF EXISTS(SELECT * FROM @filteredQueries where TableName = @tableName and SpecificColumnList is not null and SpecificColumnList not like '')
							BEGIN
								SELECT @specificColumnList = SpecificColumnList from @filteredQueries  where TableName = @tableName
								INSERT INTO @Columns(ColumnName)
								SELECT Item from dbo.fnGetTableFromCSVString(@specificColumnList)
							END
						ELSE IF EXISTS(SELECT * from @ColumnsUsed where ObjectName = @tableName)
							INSERT INTO @Columns(ColumnName)
							SELECT ColumnName from @ColumnsUsed where ObjectName = @tableName
						ELSE
							INSERT INTO @Columns(ColumnName)
							select ColumnName from @TableInfo
					

						set @lastColumnID = @@IDENTITY

						set @coulumnList  = ''
						set @coulumnList = '('
						select @coulumnList= @coulumnList + ColumnName + (CASE WHEN ColumnID = @lastColumnID THEN ')' ELSE ', ' END) from @Columns

						IF exists(select * from @filteredQueries where FullTableName = CONCAT(@schemaName,'.', @tableName))
							BEGIN
								select @filtered = Filtered, @filters = FilterWithValues from @filteredQueries where TableName = @tableName

								select @queryColumns =  @queryColumns + 
														dbo.fnGetColumnsCorrectFormatForQuery(ColumnName, @tableName) +
														(CASE WHEN ColumnID = @lastColumnID THEN ' ' ELSE ' + '', '' + ' END) + CHAR(10) from @Columns

								set @queryToExecuteOnTable = 'select ' + @queryColumns + 'from ' + CONCAT(@schemaName, '.', @tableName)

								IF @filtered = 1
									set @queryToExecuteOnTable =  @queryToExecuteOnTable + ' where ' + @filters


								INSERT INTO @filteredQueriesResults(FilteredQueryResult)
								exec tsqlt.ResultSetFilter 1, @queryToExecuteOnTable

								set @lastQueryFilteredResultID = @@IDENTITY

								select @filteredQueryResult = @filteredQueryResult + '	'+CSVToInsert + 
											(CASE WHEN FilteredQueryResultID = @lastQueryFilteredResultID THEN ' ' ELSE ', ' END) + CHAR(10) 
								from @filteredQueriesResults

							END

						set @scriptToBePrintedOut = @scriptToBePrintedOut + '	/*'+@fullTableName+'*/' + CHAR(10)
						set @scriptToBePrintedOut = @scriptToBePrintedOut + '	EXEC tSQLt.FakeTable @TableName =''' + @tableName + ''', @SchemaName = '''+ @schemaName +''', @Identity = 0, @ComputedColumns = 0, @Defaults = 0; '+ char(10)
						set @scriptToBePrintedOut = @scriptToBePrintedOut + '	INSERT INTO '+ @fullTableName +'' +@coulumnList + 
																			' VALUES ' + char(10) + @filteredQueryResult

						set @scriptToBePrintedOut = @scriptToBePrintedOut + CHAR(13)+CHAR(10)+CHAR(13)+CHAR(10)
						set @coulumnList  = ''

						select @scriptToBePrintedOut = replace(@scriptToBePrintedOut,'"','''')
						print @scriptToBePrintedOut
					
						fetch next from CURSOR_ASSOCIATED_TABLES into  @fullTableName, @schemaName, @tableName
					end
				close CURSOR_ASSOCIATED_TABLES
			deallocate CURSOR_ASSOCIATED_TABLES

	PRINT ('END' + CHAR(10)+'GO'+CHAR(10))
	print ('---------------------------------------------------------------')
	print ('-----------------------TEST CASES SECTION----------------------')
	print ('---------------------------------------------------------------')
	print ('--[TODO: Write your test cases here]'+CHAR(13))
	print ('--CREATE PROCEDURE '+@testSchemaName+'.[test <CamelCasedStateUnderTest>_<CamelCasedExpectedBehavior>]')
	PRINT('--AS'+CHAR(10)+'--BEGIN'+CHAR(10)+'	--[TODO: Write your test case''s logic here]'+CHAR(13)+CHAR(10)+'--END'+ CHAR(10)+'--GO'+CHAR(13)+CHAR(10)+CHAR(13)+CHAR(10))
	IF EXISTS(SELECT * FROM @AssociatedViews)
		BEGIN
			set @scriptToBePrintedOut = '/*NOTE: This section must be placed just after all the test cases, NOT in the Arrange section*/'+ CHAR(13)+CHAR(10)
			select @scriptToBePrintedOut = @scriptToBePrintedOut + CHAR(13)+CHAR(10)+
			'EXEC tSQLt.SetFakeViewOff' + QUOTENAME(Full_View_Name,'''') from @AssociatedViews

			print @scriptToBePrintedOut
		END

	print CHAR(13)+CHAR(10)+ 'GO' + CHAR(10) + CHAR(13) + '/* Script generated by TestClassHelper on ' + convert(VARCHAR,getdate(),0) +'*/'
	-----------------------------------------------------------------
	------------------------6. RESULTS OUTPUT------------------------
	-----------------------------------------------------------------
	select * from @AssociatedTables
	select * from @AssociatedFunctions
	select * from @AssociatedStoredProcedures
	select * from @AssociatedViews
	select * from @AssociatedUnknownObjects

END