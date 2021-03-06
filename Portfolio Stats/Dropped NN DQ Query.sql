/*dropped with contact outcome nn dq*/
WITH Dropped_NN_DQ as (
select DISTINCT t.PROSPECT_ID from ADVANCE.PROSPECT t
       LEFT OUTER JOIN ADVANCE.ASSIGNMENT A ON t.Prospect_Id = A.PROSPECT_ID AND A.ASSIGNMENT_TYPE = 'LM'
WHERE t.STOP_DATE BETWEEN TO_DATE('7/1/2015', 'MM/DD/YYYY') AND TO_DATE('6/30/2017', 'MM/DD/YYYY')
      AND t.PROSPECT_ID in (SELECT DISTINCT PROSPECT_ID FROM CONTACT_REPORT WHERE CONTACT_OUTCOME in ('NN', 'DQ'))
)

SELECT COUNT(PROSPECT_ID) AS Dropped_NN_DQ 
FROM Dropped_NN_DQ
