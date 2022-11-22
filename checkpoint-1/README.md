Content Author: Ashley Quiterio with support from Dr. Jennie Rogers.

Data: Chicago Police Department Data accessed from the Citizens Police Data Project. 
More about this data can be found here: 
http://users.eecs.northwestern.edu/~jennie/courses/data-science-seminar/cpdb-schema/index.html

The following SQL queries try to answer descriptive questions about potential patterns in 
police presence across Chicago police districts. There are 4 questions written as comments, 
and the code following attempts to answer the question. A brief 1-2 sentence implication is 
written as a comment below the code. For reference, the 4 questions asked are:

    Q1: For each Chicago police district, how many officers per capita are deployed to it? 
    (this means officers with a resignation date of NULL, example of per capita is "1 officer 
    per 1000 people"), according to the most current year of the data. This will be calculated 
    regardless of the officer’s role.

    Q2: For the two districts with the most and least (max and min) officers per capita, 
    what is their racial distribution?

    Q3: What districts have the most officer hours allocated to them per capita? 

    Q4: What is the per capita complaint rate for the top 5 districts with the highest officer 
    deployment rate? 

Please note that some of the code in later questions references temporary tables created in 
earlier questions, so please run the code in order and run all code in that question together. 
Also, since a few of the queries work with the data_officerassignmentattendance table, which has 
over 18 million cases, there is slightly longer run time. 