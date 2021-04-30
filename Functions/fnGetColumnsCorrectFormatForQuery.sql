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