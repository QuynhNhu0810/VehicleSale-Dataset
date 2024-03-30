--DATA CLEANING--
use Project
create table SALES_DATASET_RFM_PRJ
(
  ordernumber VARCHAR(50),
  quantityordered VARCHAR(50),
  priceeach        VARCHAR(50),
  orderlinenumber  VARCHAR(50),
  sales            VARCHAR(50),
  orderdate        VARCHAR(50),
  status           VARCHAR(50),
  productline      VARCHAR(50),
  msrp             VARCHAR(50),
  productcode      VARCHAR(50),
  customername    VARCHAR(50),
  phone           VARCHAR(50),
  addressline1     VARCHAR(50),
  addressline2     VARCHAR(50),
  city             VARCHAR(50),
  state           VARCHAR(50),
  postalcode      VARCHAR(50),
  country          VARCHAR(50),
  territory        VARCHAR(50),
  contactfullname  VARCHAR(50),
  dealsize         VARCHAR(50)
) 
--CHANGE DATA TYPE--
select *
from dbo.SALES_DATASET_RFM_PRJ

alter table dbo.SALES_DATASET_RFM_PRJ
alter column ordernumber int

alter table dbo.SALES_DATASET_RFM_PRJ
alter column quantityordered int

alter table dbo.SALES_DATASET_RFM_PRJ
alter column priceeach numeric

alter table dbo.SALES_DATASET_RFM_PRJ
alter column orderlinenumber int

alter table dbo.SALES_DATASET_RFM_PRJ
alter column sales numeric

alter table dbo.SALES_DATASET_RFM_PRJ
alter column orderdate datetime

alter table dbo.SALES_DATASET_RFM_PRJ
alter column msrp int

--CHECK FOR NULL OR BLANK--
delete from dbo.SALES_DATASET_RFM_PRJ
where quantityordered is null or quantityordered = '' ''

delete from dbo.SALES_DATASET_RFM_PRJ
where ordernumber is null or ordernumber = '' ''

delete from dbo.SALES_DATASET_RFM_PRJ
where priceeach is null or priceeach = '' ''

delete from dbo.SALES_DATASET_RFM_PRJ
where orderlinenumber is null or orderlinenumber = '' ''

delete from dbo.SALES_DATASET_RFM_PRJ
where sales is null or sales = '' ''

delete from dbo.SALES_DATASET_RFM_PRJ
where orderdate is null or orderdate = '' ''

--ADD AND FORMAT Last Name and First Name
alter table dbo.SALES_DATASET_RFM_PRJ
add contactlastname varchar(200)

alter table dbo.SALES_DATASET_RFM_PRJ
add contactfirstname varchar(200)

update dbo.SALES_DATASET_RFM_PRJ
set contactlastname = substring(contactfullname,1,charindex('-',contactfullname) - 1)

update dbo.SALES_DATASET_RFM_PRJ
set contactfirstname = substring(contactfullname,charindex('-',contactfullname) + 1, len(contactfullname)-charindex('-',contactfullname))

update dbo.SALES_DATASET_RFM_PRJ
set contactlastname = upper(left(contactlastname,1)) + lower(right(contactlastname,len(contactlastname)-1))

update dbo.SALES_DATASET_RFM_PRJ
set contactfirstname = upper(left(contactfirstname,1)) + lower(right(contactfirstname,len(contactfirstname)-1))

--ADD YEAR/MONTH/QUARTER--
alter table dbo.SALES_DATASET_RFM_PRJ
add qtr_id int, month_id int, year_id int

update dbo.SALES_DATASET_RFM_PRJ
set qtr_id = datepart(quarter,orderdate)

update dbo.SALES_DATASET_RFM_PRJ
set month_id = datepart(month,orderdate)

update dbo.SALES_DATASET_RFM_PRJ
set year_id = datepart(year,orderdate)

--FIND OUTLIER--
with cte as 
(
select quantityordered
,(select avg(quantityordered) from dbo.SALES_DATASET_RFM_PRJ) as avg
,(select stddev(quantityordered) from dbo.SALES_DATASET_RFM_PRJ) as stddev
from dbo.SALES_DATASET_RFM_PRJ)

,outlier as(
select quantityordered, (quantityordered-avg)/stddev as z_score
from cte
where abs(quantityordered-avg)/stddev) >3)

update dbo.SALES_DATASET_RFM_PRJ
set quantityordered = (select avg(quantityordered)
from dbo.SALES_DATASET_RFM_PRJ)
where quantityordered in (select quantityordered from outlier)

--SAVE INTO NEW TABLE--
select *
into SALES_DATASET_RFM_PRJ_CLEAN
FROM dbo.SALES_DATASET_RFM_PRJ

CREATE TABLE segment_score
(
    segment Varchar(50),
    scores Varchar(50)
)

select *
from dbo.segment_score

--EDA--
--1) Doanh thu theo từng ProductLine, Year  và DealSize--
select * 
from dbo.SALES_DATASET_RFM_PRJ
select sum(sales) as revenue
,productline
,year(orderdate) as year_order
,dealsize
from dbo.SALES_DATASET_RFM_PRJ
group by productline, year(orderdate), dealsize
--2) Đâu là tháng có bán tốt nhất mỗi năm?
select format(orderdate, 'MM-yyyy') as monthid
,sum(sales) as revenue
,count(ordernumber) as ordernumber
from dbo.SALES_DATASET_RFM_PRJ
group by format(orderdate, 'MM-yyyy')
order by 1,2 desc
--3) Product line nào được bán nhiều ở tháng 11?
select format(orderdate, 'MM-yyyy') as monthid
,count(ordernumber) as ordernumber
,productline
from dbo.SALES_DATASET_RFM_PRJ
where month(orderdate) = 11
group by format(orderdate, 'MM-yyyy'), productline
order by 1,2 desc
--4) Đâu là sản phẩm có doanh thu tốt nhất ở UK mỗi năm? 
select year_id,revenue, productline,
rank () over(order by revenue desc) as rank
from(
select year(orderdate) as year_id
,sum(sales) as revenue
,productline
,rank () over(partition by year(orderdate) order by sum(sales) desc) as ranking
from dbo.SALES_DATASET_RFM_PRJ
where country = 'UK' 
group by productline,year(orderdate)
) as r
where ranking = 1
--5) Ai là khách hàng tốt nhất, phân tích dựa vào RFM 
CREATE TABLE rfm_table (
	R DECIMAL,
	F DECIMAL,
	M DECIMAL,
    customername VARCHAR(1000),
    scores NUMERIC,
	segment VARCHAR(100),
	R_score NUMERIC,
	F_score NUMERIC,
	M_score NUMERIC,
)

;WITH rfm AS (
    SELECT 
        customername,
        DATEDIFF(day, MAX(orderdate), GETDATE()) AS R,
        COUNT(DISTINCT ordernumber) AS F,
        SUM(sales) AS M
    FROM dbo.SALES_DATASET_RFM_PRJ
    GROUP BY customername
),
rfm_score AS (
    SELECT 
		R,F,M,
        customername,
        NTILE(5) OVER (ORDER BY R DESC) AS R_score,
        NTILE(5) OVER (ORDER BY F) AS F_score,
        NTILE(5) OVER (ORDER BY M) AS M_score
    FROM rfm
),
rfm_final AS (
    SELECT 
		R,F,M,
		R_score,
		F_score,
		M_score,
        customername,
        CONCAT(R_score, F_score, M_score) AS rfm_score
    FROM rfm_score
)
INSERT INTO rfm_table (R,F,M,customername, scores,segment,R_score,F_score,M_score)
SELECT 
	a.R,a.F,a.M,
    a.customername,
    b.scores,
	b.segment,
	a.R_score,
	a.F_score,
	a.M_score
FROM rfm_final a
JOIN segment_score b ON a.rfm_score = b.scores
select * from rfm_table

