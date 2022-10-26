--[TODO: Uncomment the next line and change <DATABASE_NAME> to your database name
--USE <DATABASE_NAME>
GO

--[TODO: Set @OcjectToWriteTest as the stored procedure/function name you like to get the test class
DECLARE @ObjectToWriteTest VARCHAR(250) = ''

DECLARE @filteredQueries TestClassFilteredQueries

--[TODO: Uncomment this if you are willing to use filtered queries]
--insert into @filteredQueries(TableName, Filtered, FilterWithValues, SpecificColumnList)
--values('<TableName>', <Filtered>, <FilterWithValues>, <SpecificColumnList>),


EXEC TestClassHelper.spGetTestClass 
		@ObjectToWriteTest = @ObjectToWriteTest,
		@filteredQueries = @filteredQueries