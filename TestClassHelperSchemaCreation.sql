-- ==============================================================
-- Author:		Ruben Lopez
-- Create date: 2021-04-30
-- Description:	Helper script to build a template tSQLt Test Class
-- ===============================================================

--[TODO: Change [YOUR DATABASE NAME] with the name of your database. I.E. USE AdventureWorks2017

--USE [YOUR DATABASE NAME];
GO

IF NOT EXISTS(SELECT * FROM sys.schemas WHERE NAME = 'TestClassHelper')
	BEGIN
	 	EXEC ('CREATE SCHEMA TestClassHelper');
	END
ELSE
	BEGIN
		DROP FUNCTION TestClassHelper.fnGetColumnsCorrectFormatForQuery
		DROP FUNCTION TestClassHelper.fnGetTableFromCSVString
		EXEC ('DROP SCHEMA TestClassHelper');
	END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ====================================================
-- Author:		Ruben Lopez
-- Create date: 2021-04-30
-- Description:	Returns a table from a given CSV string
-- ====================================================
CREATE FUNCTION TestClassHelper.fnGetTableFromCSVString
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

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ===================================================================================
-- Author:		Ruben Lopez
-- Create date: 2021-04-30
-- Description:	Returns column's name in the format used at TestClassHelper script to
--				building the query that retrieves data to populate fake tables
-- ===================================================================================
CREATE FUNCTION TestClassHelper.fnGetColumnsCorrectFormatForQuery
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