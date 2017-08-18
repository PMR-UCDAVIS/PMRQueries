SELECT COUNT(PROSPECT_ID) AS "# of Prospects Added"
       , COUNT(CASE WHEN START_DATE BETWEEN TO_DATE('7/1/2015', 'MM/DD/YYYY') AND TO_DATE('6/30/2016', 'MM/DD/YYYY') THEN 1 ELSE NULL END) AS Year1
       , COUNT(CASE WHEN START_DATE BETWEEN TO_DATE('7/1/2016', 'MM/DD/YYYY') AND TO_DATE('6/30/2017', 'MM/DD/YYYY') THEN 1 ELSE NULL END) AS Year2
FROM (
  select DISTINCT P.PROSPECT_ID , P.START_DATE
  from ADVANCE.PROSPECT P
       LEFT OUTER JOIN ADVANCE.ASSIGNMENT ASGMT
            ON P.PROSPECT_ID = ASGMT.PROSPECT_ID AND ASGMT.ASSIGNMENT_TYPE = 'S'
  WHERE P.START_DATE BETWEEN TO_DATE('7/1/2015', 'MM/DD/YYYY') AND TO_DATE('6/30/2017', 'MM/DD/YYYY')
)
