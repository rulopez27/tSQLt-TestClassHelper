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