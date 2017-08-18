/*Grabbing all active prospects with dev officers*/
WITH Prospect_List as (
Select DISTINCT PROSP.Prospect_Id
       , ASGMT.ASSIGNMENT_ID_NUMBER AS RM_ID_Number
       , Prosp.Stage_Code
       , ASGMT.Start_Date
       , ASGMT.Priority_Code
from ADVANCE.PROSPECT PROSP
     LEFT OUTER JOIN ADVANCE.ASSIGNMENT ASGMT
          ON PROSP.PROSPECT_ID = ASGMT.PROSPECT_ID AND ASGMT.ACTIVE_IND = 'Y' AND ASGMT.ASSIGNMENT_TYPE = 'LM'
     LEFT OUTER JOIN ADVANCE.STAFF STAFF
          ON ASGMT.ASSIGNMENT_ID_NUMBER = STAFF.ID_NUMBER
WHERE PROSP.ACTIVE_IND = 'Y'
      AND STAFF.STAFF_TYPE_CODE = 'DEV'
)

/*Grabbing all active dev officers and their portfolio size*/
, Officer_List as (
Select  A.ASSIGNMENT_ID_NUMBER
        , S.Sort
        , COUNT(P.PROSPECT_ID) Portfolio_Size
from ADVANCE.PROSPECT P
     LEFT OUTER JOIN ADVANCE.ASSIGNMENT A
          ON P.PROSPECT_ID = A.PROSPECT_ID AND A.ACTIVE_IND = 'Y' AND A.ASSIGNMENT_TYPE = 'LM'
     LEFT OUTER JOIN ADVANCE.STAFF S
          ON A.ASSIGNMENT_ID_NUMBER = S.ID_NUMBER
WHERE P.ACTIVE_IND = 'Y'
      AND S.STAFF_TYPE_CODE = 'DEV'
GROUP BY A.ASSIGNMENT_ID_NUMBER, S.Sort
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
/*     LEFT OUTER JOIN ADVANCE.ASSIGNMENT ASGMT
          ON PROSP.PROSPECT_ID = ASGMT.PROSPECT_ID AND ASGMT.ACTIVE_IND = 'Y' AND ASGMT.ASSIGNMENT_TYPE = 'LM'*/
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
       , COUNT(CASE WHEN CR.CONTACT_TYPE = 'V' THEN 1 
                    WHEN (CR.CONTACT_TYPE in ('C', 'P') and CR.Contact_Initiated_By = 'FCGS') THEN 1
                      ELSE NULL END) Total_12M_Visit_RM
from Prospect_List Prosp
/*     LEFT OUTER JOIN ADVANCE.ASSIGNMENT ASGMT
          ON PROSP.PROSPECT_ID = ASGMT.PROSPECT_ID AND ASGMT.ACTIVE_IND = 'Y' AND ASGMT.ASSIGNMENT_TYPE = 'LM'*/
     LEFT OUTER JOIN ADVANCE.CONTACT_REPORT CR
          ON Prosp.Prospect_Id = CR.Prospect_Id AND Prosp.RM_ID_Number = CR.AUTHOR_ID_NUMBER
          AND CR.CONTACT_TYPE IN ('C', 'V', 'P', '1') 
          AND CR.CONTACT_DATE BETWEEN ADD_MONTHS(SYSDATE, -13) AND SYSDATE
GROUP BY Prosp.Prospect_Id, CR.Author_ID_NUMBER
)

/*Calculating contacts and visits by any DO in the last 12 months*/
, M12_Contacts_Any_DO as (
Select Prosp.Prospect_Id
       , COUNT(CR.CONTACT_TYPE) Total_12M_Contact_Any_DO
       , COUNT(CASE WHEN CR.CONTACT_TYPE = 'V' THEN 1 
                    WHEN (CR.CONTACT_TYPE in ('C', 'P') and CR.Contact_Initiated_By = 'FCGS') THEN 1
                      ELSE NULL END) Total_12M_Visit_Any_DO
from Prospect_List Prosp
     LEFT OUTER JOIN ADVANCE.CONTACT_REPORT CR
          ON Prosp.Prospect_Id = CR.Prospect_Id 
          AND CR.CONTACT_TYPE IN ('C', 'V', 'P', '1') 
          AND CR.CONTACT_DATE BETWEEN ADD_MONTHS(SYSDATE, -13) AND SYSDATE
GROUP BY Prosp.Prospect_Id
)

select STAFF.SORT AS RM_Name
       , OL.Portfolio_Size "Portfolio Size"
       , COUNT(CASE WHEN M12_RM.Total_12M_Contact_RM = 0 THEN NULL ELSE 1 END) "Contacted by RM"
       , COUNT(CASE WHEN M12_RM.Total_12M_Contact_RM = 0 THEN NULL ELSE 1 END) / OL.Portfolio_Size "% Contacted by RM"
       , COUNT(CASE WHEN M12_Any.Total_12M_Contact_Any_DO = 0 THEN NULL ELSE 1 END) "Contacted by Anyone"
       , COUNT(CASE WHEN M12_Any.Total_12M_Contact_Any_DO = 0 THEN NULL ELSE 1 END) / OL.Portfolio_Size "% Contacted by Anyone"
       , COUNT(CASE WHEN M12_RM.Total_12M_Visit_RM = 0 THEN NULL ELSE 1 END) "Visited by RM"
       , COUNT(CASE WHEN M12_RM.Total_12M_Visit_RM = 0 THEN NULL ELSE 1 END) / OL.Portfolio_Size "% Visited by RM"
       , COUNT(CASE WHEN M12_Any.Total_12M_Visit_Any_DO = 0 THEN NULL ELSE 1 END) "Visited by Anyone"
       , COUNT(CASE WHEN M12_Any.Total_12M_Visit_Any_DO = 0 THEN NULL ELSE 1 END) / OL.Portfolio_Size "% Visited by Anyone"
       , SYSDATE AS "Date Pulled"
       , CONCAT(CONCAT(ADD_MONTHS(SYSDATE, -13) - 1, ' - '), SYSDATE) AS "Date Range"
from Prospect_List Prosp
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
     LEFT OUTER JOIN Officer_List OL
          ON Prosp.RM_ID_Number = OL.ASSIGNMENT_ID_NUMBER
GROUP BY STAFF.SORT, OL.Portfolio_Size
ORDER BY  STAFF.SORT 
