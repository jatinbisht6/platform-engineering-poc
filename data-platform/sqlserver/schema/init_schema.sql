USE [master]
GO
/****** Object:  Database [Skaven_DW]    Script Date: 10-04-2026 01:53:23 ******/
CREATE DATABASE [Skaven_DW]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'Skaven_DW', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\Skaven_DW.mdf' , SIZE = 8192KB , MAXSIZE = UNLIMITED, FILEGROWTH = 65536KB )
 LOG ON 
( NAME = N'Skaven_DW_log', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\Skaven_DW_log.ldf' , SIZE = 8192KB , MAXSIZE = 2048GB , FILEGROWTH = 65536KB )
 WITH CATALOG_COLLATION = DATABASE_DEFAULT, LEDGER = OFF
GO
ALTER DATABASE [Skaven_DW] SET COMPATIBILITY_LEVEL = 160
GO
IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
begin
EXEC [Skaven_DW].[dbo].[sp_fulltext_database] @action = 'enable'
end
GO
ALTER DATABASE [Skaven_DW] SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE [Skaven_DW] SET ANSI_NULLS OFF 
GO
ALTER DATABASE [Skaven_DW] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [Skaven_DW] SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE [Skaven_DW] SET ARITHABORT OFF 
GO
ALTER DATABASE [Skaven_DW] SET AUTO_CLOSE OFF 
GO
ALTER DATABASE [Skaven_DW] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [Skaven_DW] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [Skaven_DW] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [Skaven_DW] SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE [Skaven_DW] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [Skaven_DW] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [Skaven_DW] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [Skaven_DW] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [Skaven_DW] SET  DISABLE_BROKER 
GO
ALTER DATABASE [Skaven_DW] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [Skaven_DW] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE [Skaven_DW] SET TRUSTWORTHY OFF 
GO
ALTER DATABASE [Skaven_DW] SET ALLOW_SNAPSHOT_ISOLATION OFF 
GO
ALTER DATABASE [Skaven_DW] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [Skaven_DW] SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE [Skaven_DW] SET HONOR_BROKER_PRIORITY OFF 
GO
ALTER DATABASE [Skaven_DW] SET RECOVERY FULL 
GO
ALTER DATABASE [Skaven_DW] SET  MULTI_USER 
GO
ALTER DATABASE [Skaven_DW] SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE [Skaven_DW] SET DB_CHAINING OFF 
GO
ALTER DATABASE [Skaven_DW] SET FILESTREAM( NON_TRANSACTED_ACCESS = OFF ) 
GO
ALTER DATABASE [Skaven_DW] SET TARGET_RECOVERY_TIME = 60 SECONDS 
GO
ALTER DATABASE [Skaven_DW] SET DELAYED_DURABILITY = DISABLED 
GO
ALTER DATABASE [Skaven_DW] SET ACCELERATED_DATABASE_RECOVERY = OFF  
GO
EXEC sys.sp_db_vardecimal_storage_format N'Skaven_DW', N'ON'
GO
ALTER DATABASE [Skaven_DW] SET QUERY_STORE = ON
GO
ALTER DATABASE [Skaven_DW] SET QUERY_STORE (OPERATION_MODE = READ_WRITE, CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 30), DATA_FLUSH_INTERVAL_SECONDS = 900, INTERVAL_LENGTH_MINUTES = 60, MAX_STORAGE_SIZE_MB = 1000, QUERY_CAPTURE_MODE = AUTO, SIZE_BASED_CLEANUP_MODE = AUTO, MAX_PLANS_PER_QUERY = 200, WAIT_STATS_CAPTURE_MODE = ON)
GO
USE [Skaven_DW]
GO
/****** Object:  Schema [Source]    Script Date: 10-04-2026 01:53:24 ******/
CREATE SCHEMA [Source]
GO
/****** Object:  Table [dbo].[DimProduct]    Script Date: 10-04-2026 01:53:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DimProduct](
	[Product Key] [int] NOT NULL,
	[ProductAlternateKey] [nvarchar](max) NULL,
	[ProductSubcategoryKey] [int] NULL,
	[ProductName] [nvarchar](max) NULL,
	[MakeFlag] [float] NULL,
	[FinishedGoodsFlag] [float] NULL,
	[Color] [nvarchar](max) NULL,
	[SafetyStockLevel] [float] NULL,
	[ReorderPoint] [float] NULL,
	[StandardCost] [money] NULL,
	[ListPrice] [money] NULL,
	[Size] [nvarchar](max) NULL,
	[SizeUnitMeasureCode] [nvarchar](max) NULL,
	[WeightUnitMeasureCode] [nvarchar](max) NULL,
	[Weight] [float] NULL,
	[DaysToManufacture] [float] NULL,
	[ProductLine] [nvarchar](max) NULL,
	[Class] [nvarchar](max) NULL,
	[Style] [nvarchar](max) NULL,
	[ProductModelID] [float] NULL,
	[SellStartDate] [datetime] NULL,
	[SellEndDate] [datetime] NULL,
	[DiscontinuedDate] [datetime] NULL,
	[rowguid] [nvarchar](255) NULL,
	[ModifiedDate] [datetime] NULL,
	[StartDate] [datetime] NULL,
	[EndDate] [varchar](255) NULL,
PRIMARY KEY CLUSTERED 
(
	[Product Key] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[DimProductCategory]    Script Date: 10-04-2026 01:53:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DimProductCategory](
	[ProductCategoryID] [int] NOT NULL,
	[ProductCategoryName] [varchar](11) NULL,
	[ModifiedDate] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[ProductCategoryID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[DimProductSubCategory]    Script Date: 10-04-2026 01:53:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DimProductSubCategory](
	[ProductSubCategoryKey] [int] NOT NULL,
	[ProductCategoryKey] [int] NULL,
	[ProductSubCategoryName] [varchar](17) NULL,
	[ModifiedDate] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[ProductSubCategoryKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Product]    Script Date: 10-04-2026 01:53:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Product](
	[ProductID] [int] NOT NULL,
	[Name] [nvarchar](max) NULL,
	[ProductNumber] [nvarchar](max) NULL,
	[MakeFlag] [float] NULL,
	[FinishedGoodsFlag] [float] NULL,
	[Color] [nvarchar](max) NULL,
	[SafetyStockLevel] [float] NULL,
	[ReorderPoint] [float] NULL,
	[StandardCost] [money] NULL,
	[ListPrice] [money] NULL,
	[Size] [nvarchar](max) NULL,
	[SizeUnitMeasureCode] [nvarchar](max) NULL,
	[WeightUnitMeasureCode] [nvarchar](max) NULL,
	[Weight] [float] NULL,
	[DaysToManufacture] [float] NULL,
	[ProductLine] [nvarchar](max) NULL,
	[Class] [nvarchar](max) NULL,
	[Style] [nvarchar](max) NULL,
	[ProductSubcategoryID] [float] NULL,
	[ProductModelID] [float] NULL,
	[SellStartDate] [datetime] NULL,
	[SellEndDate] [datetime] NULL,
	[DiscontinuedDate] [datetime] NULL,
	[rowguid] [nvarchar](255) NULL,
	[ModifiedDate] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[ProductID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[ProductKeyLookup]    Script Date: 10-04-2026 01:53:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ProductKeyLookup](
	[Product Key] [int] NOT NULL,
	[ProductID] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[Product Key] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[DimProduct]  WITH CHECK ADD FOREIGN KEY([ProductSubcategoryKey])
REFERENCES [dbo].[DimProductSubCategory] ([ProductSubCategoryKey])
GO
ALTER TABLE [dbo].[DimProductSubCategory]  WITH NOCHECK ADD FOREIGN KEY([ProductCategoryKey])
REFERENCES [dbo].[DimProductCategory] ([ProductCategoryID])
GO
USE [master]
GO
ALTER DATABASE [Skaven_DW] SET  READ_WRITE 
GO
