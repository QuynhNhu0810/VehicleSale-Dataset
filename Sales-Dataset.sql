
CREATE TABLE segment_score
(
    segment Varchar(50),
    scores Varchar(50)
)

select *
from dbo.segment_score

use Project
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
with rfm as (
select customername
,datediff(day, max(orderdate), getdate()) as R
,count(distinct ordernumber) as F
,sum(sales) as M
from dbo.SALES_DATASET_RFM_PRJ
group by customername)

,rfm_score as(
select customername
,ntile(5) over (order by R desc) as R_score
,ntile(5) over (order by F) as F_score
,ntile(5) over (order by M) as M_score
from rfm)

,rfm_final as(
select customername,
concat(R_score, F_score, M_score) as rfm_score
from rfm_score)


select a.customername, b.scores
from rfm_final a
join segment_score b on a.rfm_score = b.scores
where segment = 'Champions'
order by 2 desc
