# tSQLt-TestClassHelper
A tool to easily build a new tSQLt Test Class that will include the arrange section user defined functions, user defined stored procedures and tables which the object to be tested depends. It also will let you fake those tables with actuall data taken from you development database to be populating those fake tables.

## 1. Getting Started
Since this is a tool derived from the existing tSQLt Framework (https://tsqlt.org) You need to know at least what tSQLt and a Test Class are. You can check their documentation and User Guide before using this tool.
Once you have enough knowledge on tSQLt Framework, make sure you have already installed it in your development environement. This is important because it uses some resources of this framework in order create the test class script template. If this framework is not installed yet, proceed to install it from https://tsqlt.org/downloads/

Remember this is a project still on development, so it could have some bugs. Feel to fork this repo and modify it for your own purposes, you can always contribute to this project by creating a PR so I can integrate your features.

## 2. Instructions

### 2.1	To get a test class script from a stored procedure or function
Go to line 152 and chage @ObjectToWriteTests variable value to the name of the stored procedure or function you want to test. I.E.:

	@ObjectToWriteTest = 'uspMyStoredProcedure'

I recommend to exclude "dbo" if that's your stored procedure/function schema, otherwise include schema name.

### 2.2	To populate fake tables with filtered data from your development database
I've include a functionallity that will allow you to populate fake tables with data from your development database. It also has a logic to get which columns are used for every used table. This is completely optional but its a good tool if you want to use it. Remember not to include sensitive data.

To do this there is a table valued variable called @filteredQueries that you can use to write your own filters for those tables you want to filter. Just uncomment lines 164 and 165 and insert the following:
*	SchemaName: Nullable field. Table's schema name ("dbo" is default if not supplied).
*	TableName: Mandatory field. Table name.
*	Filtered: Mandatory field. True (1) if you want to apply a filter, otherwise False (0)
*	FilterWithValues: Nullable field. Filters after "WHERE" sentence on a normal query. I.E.: "RecordID = 1 AND IsActive = 1".
*	SpecificColumns: Nullable field. You can specify your own columns collection. I.E.: "RecordID, Description, IsActive, ModifiedOn".

Here's an example of how to populate to use this feature:

	--[TODO: Uncomment this if you are willing to use filtered queries]
	INSERT INTO @filteredQueries(SchemaName, TableName, Filtered, FilterWithValues, SpecificColumnList) VALUES
	('Production', 'Product', 1, 'ProductID = 3', 'ProductID, Name, ProductNumber, MakeFlag, ModifiedDate'),
	('Production', 'BillOfMaterials', 1, 'ProductAssemblyID = 3', NULL)

## 3.	Execution

### Result Sets
You can either press F5 or Execute to run this script. The script will return you 5 result sets in the following order:
*	Tables referenced.
*	Functions referenced.
*	Stored Procedures referenced.
*	Views referenced.
*	Unknown objects referenced


### Test Class
Switch to Messages tab, you will find your test class script. Copy and paste it in another query window. Test class script contains the following sections (Using AdventureWorks2019 database from Microsoft with few customizations):
*	Test Class creation
			
		USE [AdventureWorks2019]
		GO

		EXEC [AdventureWorks2019].[tSQLt].NewTestClass 'uspGetBillOfMaterialsTests'
		GO

*	Fake Functions (if there is any function dependency). You will need to write the right variables and the fake logic here.

		---------------------------------------------------------------
		-------------------FAKE FUNCTIONS SECTION----------------------
		---------------------------------------------------------------
		--[TODO: Fake your functions here]

		/*dbo.usfnGetProductSubAssemblyCount*/
		--CREATE FUNCTION uspGetBillOfMaterialsTests.usfnGetProductSubAssemblyCount_Test (@variable1 <dataType1>, @variable2 <dataType2>)
		--RETURNS <returnDataType>
		--AS
		--BEGIN
			--[TODO: Write your fake function's code here]
		--END
		--GO

*	Arrange and Set Up

		---------------------------------------------------------------
		-----------------------ARRANGE SECTION-------------------------
		---------------------------------------------------------------
		CREATE PROCEDURE uspGetBillOfMaterialsTests.SetUp
		AS
		BEGIN
			/*	[TODO: Customize your fake tables process by doing the following]
					1. Changing the value of the variables sent to each tSQLt.FakeTable stored procedure in order to meet your needs. 
					2. If you do not need any data to be populated in a fake table, just remove the INSERT INTO statement from the table you need
			*/
			
			/*Arrange Views*/
			DECLARE @sqlCommand NVARCHAR(MAX) = ''
			EXEC tSQLt.SetFakeViewOn 'Production.vProductAndDescription'
			
			/*Arrange Functions*/
			EXEC tSQLt.FakeFunction 'dbo.usfnGetProductSubAssemblyCount', 'uspGetBillOfMaterialsTests.usfnGetProductSubAssemblyCount_Test'
			
			
			/*Production.BillOfMaterials*/
			EXEC tSQLt.FakeTable @TableName ='BillOfMaterials', @SchemaName = 'Production', @Identity = 0, @ComputedColumns = 0, @Defaults = 0; 
			INSERT INTO Production.BillOfMaterials(BillOfMaterialsID, ProductAssemblyID, ComponentID, StartDate, EndDate, UnitMeasureCode, BOMLevel, PerAssemblyQty,ModifiedDate) VALUES 
			(2000, 3, 2, 'Jul  8 2010 12:00AM', NULL, 'EA ', 3, 10.00, 'Jun 24 2010 12:00AM'), 
			(1657, 3, 461, 'Jun 19 2010 12:00AM', NULL, 'EA ', 3, 1.00, 'Jun  5 2010 12:00AM'), 
			(389, 3, 504, 'Mar 18 2010 12:00AM', NULL, 'EA ', 3, 2.00, 'Mar  4 2010 12:00AM'), 
			(805, 3, 505, 'May 26 2010 12:00AM', NULL, 'EA ', 3, 2.00, 'May 12 2010 12:00AM')


			/*Production.Product*/
			EXEC tSQLt.FakeTable @TableName ='Product', @SchemaName = 'Production', @Identity = 0, @ComputedColumns = 0, @Defaults = 0; 
			INSERT INTO Production.Product(ProductID, Name, ProductNumber, MakeFlag,  ModifiedDate) VALUES 
			(3, 'BB Ball Bearing', 'BE-2349', 1, 'Feb  8 2014 10:01AM') 
		END
		GO

*	Test Case templates

		---------------------------------------------------------------
		-----------------------TEST CASES SECTION----------------------
		---------------------------------------------------------------
		--[TODO: Write your test cases here]

		--CREATE PROCEDURE uspGetBillOfMaterialsTests.[test <CamelCasedStateUnderTest>_<CamelCasedExpectedBehavior>]
		--AS
		--BEGIN
			--[TODO: Write your test case's logic here]
		--END
		--GO		

*	Views Fake Off (if any)

		/*NOTE: This section must be placed just after all the test cases, NOT in the Arrange section*/

		EXEC tSQLt.SetFakeViewOff'Production.vProductAndDescription'
		GO

*	Execution date and time

		/* Script generated by TestClassHelper on Oct 25 2022  9:20PM*/

## Observations and Suggestions
Some things that I have found using it against my own projects is
*	Since script is using DB_NAME() to write the database name in the USE sentece, it will print this kind of legend (Remove it from the script after saving it in another query window).

		In the current database, the specified object references the following:


*	Line endings won't match CR LF format. To solve this you can copy and paste the generated test class in another query window and save it with format.
*	Populating UNIQUEIDENTIFIER columns is not possible yet. It crashes most of the time because all filtered data is converted to a NVARCHAR string. Try to avoid those fields.
*	You still need to populate faked views. Use @CMD variable to write an "INSERT INTO" statemement to insert fake data to the fake view. Then use and reset it when needed

		EXEC @CMD

