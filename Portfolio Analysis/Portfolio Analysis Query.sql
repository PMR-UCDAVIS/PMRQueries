/*Grabbing all active prospects with dev officers*/
WITH Prospect_List as (
Select DISTINCT PROSP.Prospect_Id
       , ASGMT.ASSIGNMENT_ID_NUMBER AS RM_ID_Number
       , Prosp.Stage_Code
       , CASE WHEN ASGMT.Start_Date IS NULL THEN ASGMT.DATE_ADDED
              ELSE ASGMT.Start_Date END AS Start_Date
       , ASGMT.Priority_Code
from ADVANCE.PROSPECT PROSP
     LEFT OUTER JOIN ADVANCE.ASSIGNMENT ASGMT
          ON PROSP.PROSPECT_ID = ASGMT.PROSPECT_ID AND ASGMT.ACTIVE_IND = 'Y' AND ASGMT.ASSIGNMENT_TYPE = 'LM'
     LEFT OUTER JOIN ADVANCE.STAFF STAFF
          ON ASGMT.ASSIGNMENT_ID_NUMBER = STAFF.ID_NUMBER
WHERE PROSP.ACTIVE_IND = 'Y'
      AND STAFF.STAFF_TYPE_CODE = 'DEV'
)

/*Calculating contacts and visits by the RM*/
, All_Contacts_RM as (
Select Prosp.Prospect_Id
       , CR.Author_ID_NUMBER
       , COUNT(CR.CONTACT_TYPE) Total_Contact_RM
       , COUNT(CASE WHEN CR.CONTACT_TYPE = 'V' THEN 1 
                    WHEN (CR.CONTACT_TYPE in ('C', 'P') and CR.Contact_Initiated_By = 'FCGS') THEN 1
                      ELSE NULL END) Total_Visit_RM
       , MAX(CASE WHEN CR.CONTACT_TYPE = 'V' THEN CR.CONTACT_DATE 
                  WHEN (CR.CONTACT_TYPE in ('C', 'P') and CR.Contact_Initiated_By = 'FCGS') THEN CR.CONTACT_DATE 
                    ELSE NULL END) Most_Recent_Visit_RM
from Prospect_List Prosp
     LEFT OUTER JOIN ADVANCE.CONTACT_REPORT CR
          ON Prosp.Prospect_Id = CR.Prospect_Id AND Prosp.RM_ID_Number = CR.AUTHOR_ID_NUMBER
          AND CR.CONTACT_TYPE IN ('C', 'V', 'P', '1')
GROUP BY Prosp.Prospect_Id, CR.Author_ID_NUMBER
)

/*Calculating contacts and visits by all DO's*/
, All_Contacts_Any_DO as (
Select Prosp.Prospect_Id
       , COUNT(CR.CONTACT_TYPE) Total_Contact_Any_DO
       , COUNT(CASE WHEN CR.CONTACT_TYPE = 'V' THEN 1 
                    WHEN (CR.CONTACT_TYPE in ('C', 'P') and CR.Contact_Initiated_By = 'FCGS') THEN 1
                      ELSE NULL END) Total_Visit_Any_DO
       , MAX(CASE WHEN CR.CONTACT_TYPE = 'V' THEN CR.CONTACT_DATE 
                  WHEN (CR.CONTACT_TYPE in ('C', 'P') and CR.Contact_Initiated_By = 'FCGS') THEN CR.CONTACT_DATE 
                    ELSE NULL END) Most_Recent_Visit_Any_DO
from Prospect_List Prosp
     LEFT OUTER JOIN ADVANCE.CONTACT_REPORT CR
          ON Prosp.Prospect_Id = CR.Prospect_Id 
          AND CR.CONTACT_TYPE IN ('C', 'V', 'P', '1')
GROUP BY Prosp.Prospect_Id
)

/*Calculating contacts and visits by the RM in the last 12 months*/
, M12_Contacts_RM as (
Select Prosp.Prospect_Id
       , CR.Author_ID_NUMBER
       , COUNT(CR.CONTACT_TYPE) Total_12M_Contact_RM
       , COUNT(CASE WHEN CR.CONTACT_TYPE = 'V' THEN CR.CONTACT_DATE 
                  WHEN (CR.CONTACT_TYPE in ('C', 'P') and CR.Contact_Initiated_By = 'FCGS') THEN CR.CONTACT_DATE 
                    ELSE NULL END) Total_12M_Visit_RM
from Prospect_List Prosp
     LEFT OUTER JOIN ADVANCE.CONTACT_REPORT CR
          ON Prosp.Prospect_Id = CR.Prospect_Id AND Prosp.RM_ID_Number = CR.AUTHOR_ID_NUMBER
          AND CR.CONTACT_TYPE IN ('C', 'V', 'P', '1') 
          AND CR.CONTACT_DATE BETWEEN (ADD_MONTHS(SYSDATE, -13) - 1) AND SYSDATE
GROUP BY Prosp.Prospect_Id, CR.Author_ID_NUMBER
)

/*Calculating contacts and visits by any DO in the last 12 months*/
, M12_Contacts_Any_DO as (
Select Prosp.Prospect_Id
       , COUNT(CR.CONTACT_TYPE) Total_12M_Contact_Any_DO
       , COUNT(CASE WHEN CR.CONTACT_TYPE = 'V' THEN CR.CONTACT_DATE 
                  WHEN (CR.CONTACT_TYPE in ('C', 'P') and CR.Contact_Initiated_By = 'FCGS') THEN CR.CONTACT_DATE 
                    ELSE NULL END) Total_12M_Visit_Any_DO
from Prospect_List Prosp
     LEFT OUTER JOIN ADVANCE.CONTACT_REPORT CR
          ON Prosp.Prospect_Id = CR.Prospect_Id 
          AND CR.CONTACT_TYPE IN ('C', 'V', 'P', '1') 
          AND CR.CONTACT_DATE BETWEEN (ADD_MONTHS(SYSDATE, -13) - 1) AND SYSDATE
GROUP BY Prosp.Prospect_Id
)

/*Calculating last giving date for all prospects*/
, Giving as (
SELECT GVG.ID_NUMBER
         , GVG.DATE_OF_RECORD
         , ROW_NUMBER() OVER (PARTITION BY GVG.ID_NUMBER ORDER BY GVG.DATE_OF_RECORD DESC) AS rn
FROM Prospect_List Prosp
     LEFT OUTER JOIN ADVANCE.UCDR_PROSPECT_POOL Pool 
          ON PROSP.PROSPECT_ID = Pool.Prosp_Id AND Pool.Prim_Prosp_Ind = 'Y'
     LEFT OUTER JOIN ADVANCE.UCDR_GIVING GVG
          ON POOL.ID_NUMBER = GVG.ID_NUMBER
WHERE GVG.GIVING_IND in ('P', 'G')
) 

/*Calculating last giving date and amount for Annual Fund*/
, Annual_Fund as (
SELECT GV.ID_NUMBER
         , GV.DATE_OF_RECORD
         , GV.PRIM_AMT
         , ROW_NUMBER() OVER (PARTITION BY GV.ID_NUMBER ORDER BY GV.DATE_OF_RECORD DESC) AS rn
FROM Prospect_List Prosp
     LEFT OUTER JOIN ADVANCE.UCDR_PROSPECT_POOL Pool 
          ON PROSP.PROSPECT_ID = Pool.Prosp_Id AND Pool.Prim_Prosp_Ind = 'Y'
     LEFT OUTER JOIN ADVANCE.UCDR_GIVING GV
          ON POOL.ID_NUMBER = GV.ID_NUMBER
WHERE GV.Prog_Hier_Num = '1' AND GV.GIVING_IND in ('P', 'G')
) 

/*Finding qualification  and qualification date for all prospects*/
, MG_Qualified as (
Select CR.Prospect_Id
       , CR.CONTACT_OUTCOME
       , CR.Contact_Date AS Most_Recent_MG_Qualification
       , ROW_NUMBER() OVER (PARTITION BY CR.Prospect_Id ORDER BY CR.Contact_Date DESC) AS rn
FROM Prospect_List Prosp 
     LEFT OUTER JOIN ADVANCE.CONTACT_REPORT CR
          ON CR.PROSPECT_ID = Prosp.Prospect_Id
WHERE CONTACT_OUTCOME NOT IN ('DU', 'QO', ' ')
)


select Prosp.PROSPECT_ID  
       , Pool.Id_Number AS Entity_ID
       , Pool.Pers_Org_Ind
       , Pool.Sort_Name AS "Prospect Name"
       , Pool.Pref_Mail_Name
       , POOL.AGE
       , POOL.SPOUSE_AGE
       , POOL.RECORD_TYPE_CODE
       , POOL.SPOUSE_RECORD_TYPE_CODE
       , POOL.Home_Business_State
       , POOL.HOME_BUSINESS_COUNTY
       , STAFF.SORT AS RM_Name
       , UC.FULL_DESC AS RM_Area
       , CASE WHEN Prosp.PRIORITY_CODE = 'PQ' THEN Prosp.Start_Date
         ELSE NULL 
         END AS "PQ Assign Date"
       , CASE WHEN Prosp.PRIORITY_CODE = 'PM' THEN Prosp.Start_Date
         ELSE NULL 
         END AS "PM Assign Date"
       , (SELECT MAX(INITIAL_CONTRIBUTION_DATE) FROM ADVANCE.PROPOSAL P WHERE P.PROPOSAL_TYPE like 'MG%' 
         AND P.Active_Ind = 'Y' AND P.Stage_Code = 'RB' AND POOL.HIGH_ACT_ASK_PLAN = P.ASK_AMT
         AND Prosp.PROSPECT_ID = p.prospect_id) AS HIGH_ACT_ASK_PLAN_DATE
       , POOL.HIGH_ACT_ASK_PLAN
       , POOL.Highest_Active_Ask
       , POOL.Abs_High_Capacity_Ucdt_Asks
       , POOL.Abs_High_Capacity_Ucdt_Ask_Lvl
       , POOL.HIGH_UCDT_OR_CAPACITY
       , POOL.Lifetime_Giving_Devel
       , POOL.FIRST_FY_GIFT, POOL.FIRST_FY_MAJOR_GIFT
       , POOL.LAST_FY_GIFT, POOL.LAST_FY_MAJOR_GIFT
       , POOL.Nbr_Giving_Yrs
       , POOL.Nbr_Of_Gifts
       , POOL.Gift_In_Each_Of_Last_3_Fy
       , POOL.Last_Contact_Date, POOL.Last_Contact_Author
       , POOL.LAST_CONTACT_ATTEMPT AS LAST_CONTACT_ATTEMPT_DATE, POOL.Last_Contact_Attempt_Auth
       , POOL.Date_Last_Face_2_Face
       , POOL.LAST_FACE2FACE_AUTHOR
       , POOL.Date_Last_Mg_Ask
       , POOL.Last_Mg_Ask_Author
       , CASE WHEN (SYSDATE - Prosp.Start_Date) / 12 < 18 THEN 'RM < 18 Mo'
              WHEN (SYSDATE - POOL.Date_Last_Mg_Ask) / 12 >= 18 THEN 'Y'
              ELSE 'N' END AS "RM 18 mnths but no MG Ask"
       , AF.PRIM_AMT AS AF_Last_Amt
       , AF.DATE_OF_RECORD AS AF_Last_Date
       , ST.FULL_DESC AS "Prospect Stage"
       , MG.CONTACT_OUTCOME AS "Most Recent MG Qualified Code"
       , MG.Most_Recent_MG_Qualification AS "Most Recent MG Qualified Date"
       , M12_RM.Total_12M_Contact_RM AS "C,P,V,Atmpt by RM (12 Mnths)"
       , AC_RM.Total_Contact_RM AS "C,P,V,Atmpt by RM)"
       , M12_RM.Total_12M_Visit_RM AS "Visits by RM (12 Mnths)"
       , AC_RM.Total_Visit_RM AS "Visits by RM"
       , AC_RM.Most_Recent_Visit_RM AS "Most Recent Visit by RM"
       , M12_Any.Total_12M_Contact_Any_DO AS "C,P,V,Atmpt Any DO (12 Mnths)"
       , AC_Any.Total_Contact_Any_DO "C,P,V,Atmpt Any DO"
       , M12_Any.Total_12M_Visit_Any_DO AS "Visits Any DO (12 Mnths)"
       , AC_Any.Total_Visit_Any_DO AS "Visits Any DO"
       , AC_Any.Most_Recent_Visit_Any_DO AS "Most Recent Visit Any DO"
       , ROUND((SYSDATE - Prosp.Start_Date) / 365, 2) AS Years_As_RM
       , G.DATE_OF_RECORD AS Last_Gift_Date
       , CASE WHEN Pool.Pers_Org_Ind = 'O' THEN NULL
         WHEN ROUND((SYSDATE - Prosp.Start_Date) / 365, 2) < .5 THEN 'ORANGE'
         WHEN (POOL.Abs_High_Capacity_Ucdt_Asks < 50000 AND POOL.Lifetime_Giving_Devel < 50000) THEN 'RED'
         WHEN (POOL.Abs_High_Capacity_Ucdt_Asks < 100000 AND (POOL.Lifetime_Giving_Devel = 0 OR POOL.Lifetime_Giving_Devel IS NULL)
              AND M12_Any.Total_12M_Visit_Any_DO = 0) THEN 'RED'
         WHEN (POOL.Abs_High_Capacity_Ucdt_Asks >= 50000 AND (M12_RM.Total_12M_Visit_RM = 0 OR M12_RM.Total_12M_Visit_RM IS NULL) AND ROUND((SYSDATE - Prosp.Start_Date) / 365, 2) >= 2) THEN 'YELLOW'
         WHEN (POOL.Abs_High_Capacity_Ucdt_Asks >= 50000 AND ST.FULL_DESC <> 'Active Solicitation' AND ROUND((SYSDATE - Prosp.Start_Date) / 365, 2) >= 1 AND G.DATE_OF_RECORD BETWEEN ADD_MONTHS(SYSDATE, -13) AND SYSDATE) THEN 'YELLOW'
         WHEN (POOL.Abs_High_Capacity_Ucdt_Asks >= 50000 AND M12_RM.Total_12M_Contact_RM >= 1) THEN 'GREEN'
         WHEN (POOL.Abs_High_Capacity_Ucdt_Asks >= 50000 AND M12_Any.Total_12M_Visit_Any_DO >= 1) THEN 'GREEN'
         WHEN (ROUND((SYSDATE - Prosp.Start_Date) / 365, 2) >= 1 AND AC_RM.Total_Contact_RM = 0) THEN 'YELLOW2'
         ELSE NULL
         END AS Assessment
       , CASE WHEN Pool.Pers_Org_Ind = 'O' THEN NULL
         WHEN ROUND((SYSDATE - Prosp.Start_Date) / 365, 2) < .5 THEN 'In Portfolio < 6 months'
         WHEN (POOL.Abs_High_Capacity_Ucdt_Asks < 50000 AND POOL.Lifetime_Giving_Devel < 50000) THEN 'Highest MG Capacity < $50k and Lifetime Giving < $50k'
         WHEN (POOL.Abs_High_Capacity_Ucdt_Asks < 100000 AND (POOL.Lifetime_Giving_Devel = 0 OR POOL.Lifetime_Giving_Devel IS NULL)
              AND M12_Any.Total_12M_Visit_Any_DO = 0) THEN 'Highest MG Capacity < $100k and No Visit By Any DO in 12 Months and No Giving Ever'
         WHEN (POOL.Abs_High_Capacity_Ucdt_Asks >= 50000 AND (M12_RM.Total_12M_Visit_RM = 0 OR M12_RM.Total_12M_Visit_RM IS NULL) AND ROUND((SYSDATE - Prosp.Start_Date) / 365, 2) >= 2) THEN 'Highest MG Capacity > $50k and No F2F By RM and Years As RM > 2yrs'
         WHEN (POOL.Abs_High_Capacity_Ucdt_Asks >= 50000 AND ST.FULL_DESC <> 'Active Solicitation' AND ROUND((SYSDATE - Prosp.Start_Date) / 365, 2) >= 1 AND G.DATE_OF_RECORD BETWEEN ADD_MONTHS(SYSDATE, -13) AND SYSDATE) THEN 'Highest MG Capacity > $50k and Any Gift Within Past 12 Months and Not Active Solicitation'
         WHEN (POOL.Abs_High_Capacity_Ucdt_Asks >= 50000 AND M12_RM.Total_12M_Contact_RM >= 1) THEN 'Highest MG Capacity > $50k and Contact By RM in 12 Months'
         WHEN (POOL.Abs_High_Capacity_Ucdt_Asks >= 50000 AND M12_Any.Total_12M_Visit_Any_DO >= 1) THEN 'Highest MG Capacity > $50k and Any F2F in 12 Months'
         WHEN (ROUND((SYSDATE - Prosp.Start_Date) / 365, 2) >= 1 AND AC_RM.Total_Contact_RM = 0) THEN 'Not Red, Yellow, or Green and RM > 1yr and No Contact By RM ever'
         ELSE NULL
         END AS Assessment_Reason 
       , SYSDATE AS "Date Pulled"
       , CONCAT(CONCAT(ADD_MONTHS(SYSDATE, -13) - 1, ' - '), SYSDATE) AS "Date Range"
from Prospect_List Prosp
     LEFT OUTER JOIN ADVANCE.UCDR_PROSPECT_POOL Pool 
          ON PROSP.PROSPECT_ID = Pool.Prosp_Id AND Pool.Prim_Prosp_Ind = 'Y'
     LEFT OUTER JOIN ADVANCE.STAFF STAFF
          ON Prosp.RM_ID_Number = STAFF.ID_NUMBER
     LEFT OUTER JOIN All_CONTACTS_RM AC_RM
          ON Prosp.Prospect_ID = AC_RM.Prospect_ID
     LEFT OUTER JOIN M12_Contacts_RM M12_RM
          ON Prosp.Prospect_ID = M12_RM.Prospect_ID
     LEFT OUTER JOIN All_CONTACTS_Any_DO AC_Any
          ON Prosp.Prospect_ID = AC_Any.Prospect_ID
     LEFT OUTER JOIN M12_Contacts_Any_DO M12_Any
          ON Prosp.Prospect_ID = M12_Any.Prospect_ID
     LEFT OUTER JOIN Giving G
          ON POOL.ID_NUMBER = G.ID_NUMBER and G.rn = 1
     LEFT OUTER JOIN Annual_Fund AF
          ON POOL.ID_NUMBER = AF.ID_NUMBER and AF.rn = 1
     LEFT OUTER JOIN ADVANCE.TMS_UNIT_CODE UC
          ON STAFF.UNIT_CODE = UC.Unit_Code
     LEFT OUTER JOIN ADVANCE.TMS_STAGE ST
          ON PROSP.STAGE_CODE = ST.STAGE_CODE
     LEFT OUTER JOIN MG_Qualified MG
          ON PROSP.PROSPECT_ID = MG.PROSPECT_ID
             AND MG.rn = 1
