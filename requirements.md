<!-- markdownlint-disable MD025 -->
# 1. Background & Goals

## Current Situation

Company's transactional contracts data is stored in a large Excel file that tracks every closed/won sales deal (as well as renewals, upgrades/downgrades, cancels, & de-books). Key issues include:

• **Performance:** Excel becomes slow with increasing data.
• **Accessibility:** The file is stored on a network drive and editable by only one person at a time if and only if they have access to the Finance shared drive, and are either in a Company office, or connected to the Company VPN.
• **Scalability & Collaboration:** Limited support for multi-user access and concurrent data manipulation.

## Goals for the New System

• Replace the Excel file with a robust, multi-user, database-backed system.
• Ensure fast performance, high availability, and secure access.
• Support complex business logic (e.g., varying term lengths and dynamic revenue calculations).
• Provide scalability and easy integration with other business systems (e.g., CRM, CPM, & analytics platforms).

# 2. Functional Requirements

## 2.1 Data Model & Core Entities

Our new system should capture the key sales deal attributes and support relationships between them. Suggested core entities include:

• **Order:**

- **Order Number:** A unique identifier for each deal.
- **Sold Date:** The date the deal was closed.
- **TCV (Total Contract Value):** Total deal value incorporating escalators and one-time fees.

• **Customer:**

- **Customer Name:** The full name or company name.
- **Customer ID:** Unique identifier for each customer (could potentially re-use Accounting Information System customer ID)
- **Contact Details:** (Optional) Email, phone, and address information (billing contact, technical contact, etc).

• **Service:**
  For each service in an order, track:

- **Service Type/Name:** What service was sold.
- **Term Length:** Number of months for the service (may vary per service within one order).
- **Service Status:** Enum values such as pending installation, active, extended (beyond contract term), canceled, or renewed.
- **Service Start and End Dates:** Dates effective once installation begins.
- **Units:** Quantity or other measure depending on the service type.
- **Unit Price:** Cost per unit.
- **NRCs:** Any non-recurring fees associated with the service.

• **Revenue & Calculations:**
  These fields may be computed fields or stored for historical record:

- **MRR (Monthly Recurring Revenue)**
- **ARR (Annual Recurring Revenue)**
- **GAAP MRR:** Calculated by taking the TCV minus any NRCs, then dividing by the contract term.
- **Annual Escalator:** The percentage increase applied yearly.
- **Dynamic TCV Calculation:** Should incorporate annual escalators and other adjustments, uses formula for the future value of an annuity due + NRCs to calculate:
  - FV(Annuity Due) = C × [(1+i)^n - 1 / i] × (1+i) + NRCs
    - C = cash flow per period
    - i = interest rate
    - n = number of payments

## 2.2 Transaction Management & CRUD Operations

• **Create, Read, Update, Delete (CRUD):** Provide full lifecycle management for orders, services, and customer details.
• **Batch Imports/Exports:** Ability to import legacy Excel data (with mapping wizard) and export current data to common formats (CSV, Excel, PDF for reporting).
• **Audit Trails:** Log changes to key fields (e.g., service status changes, recalculation of revenue fields) for traceability.

## 2.3 Business Logic & Calculations

• **Dynamic Revenue Calculations:**
  The system should support automated computation of:

- MRR, ARR, GAAP MRR based on input data.
- Adjustments due to varying term lengths or changes in escalator percentages.

• **Service Status Transitions:** Provide workflows for updating a service's status (such as transitioning from "pending installation" to "active").

• **Renewals/Upgrades/Downgrades**

- Any subsequent transaction that is somehow modifying a previously won contract should only track the net new MRR/TCV/other metric.
  - Example 1: order ABC for 1 cabinet and 2kW of power for $1,000 baseline MRR and 36 months @ 3% annual escalator is renewed by order DEF at the end of the initial term for $1,100 baseline MRR for an additional 36 months at the same annual escalator, and billing for the renewal doesn't start until the full initial term is complete:
    - Order ABC Baseline MRR = $1,000, GAAP MRR = $1,030.30, TCV = $37,090.80
    - Order DEF Baseline MRR = $1,100, GAAP MRR = $1,133.33, TCV = $40,799.88
    - At the time of renewal, the net incremental MRR is $100 (renewal order baseline MRR – original order baseline MRR), however incremental TCV is the full $40,799.88.
  - Example 2: same details as example 1, except the customer wants the renewal to start right away (say for example if they are buying other services and want the existing services to co-term with their new services, and let's say the renewal rate would kick in 3 months prior to the end of the initial term), DEF contract term is still for 36 months:
    - Order ABC Baseline MRR = $1,000, GAAP MRR = $1,030.30, TCV = $37,090.80
    - Order DEF Baseline MRR = $1,100, TCV = $40,799.88 **LESS** 3 months' worth of order ABC
      - The last three months of order ABC is worth $3,182.70
      - Order DEF TCV is then $37,617.18, and thus GAAP MRR = $1,044.92, and net incremental MRR is still $100
- Transactions modifying a previously won contract should keep track of the "original order" so we can track the life of an order

• **Alerts & Notifications:**
  Trigger alerts for events like:

- Upcoming service start/end dates.
- Contracts nearing renewal or exceeding term length.

## 2.4 Reporting & Analytics

• **Custom Reports:**
  Ability to generate real-time reports and dashboards covering:

- Sales performance over time (e.g., total TCV, aggregated MRR/ARR).
- Rent Roll as of a given date showing which customers have services (active or pending install) per site, the MRR, TCV, NOI, kW, & cabinets
- BBNB – booked but not billed – as of a given date showing per site MRR, TCV, NOI, kW, & cabinets
- Billing and rev rec schedules at varying levels of aggregation
- Churn reporting:
  - We define churn as the reduction of the installed revenue base (cancels and downgrades)
  - De-books were never installed, thus shouldn't be included in churn reporting
- Renewals reporting:
  - Contracts/services up for renewal in the next "n" months (determined at report runtime)
  - Ability to show the original MRR (e.g. initial contract), renewed MRR (new contract), uplift/downgrade over/below original MRR, and non-renewed services
- Operational reporting: friendly output for Ops personnel to tick and tie their layout maps to, ensuring we're in sync (customer, kW, cabinet count)

• **Filtering & Drill-Down Capabilities:** Users should be able to filter by customer, service type, date ranges, or status, sales rep, site, etc.
• **Historical Analysis:** Track changes over time, including service updates, renewals, or cancellations.
• **Analytics:** Be able to calculate things like price/kW (or the relevant metric for the specific service, e.g. price/Gbps for bandwidth related services), weighted average remaining term (per customer/site/entire platform)

## 2.5 User Interface (UI) & User Experience (UX)

• **Dashboard Interface:** A central dashboard displaying key metrics and summary views.
• **Responsive Design:** Accessible on desktops, laptops, and potentially mobile devices.
• **User-Friendly Data Entry:** Forms with validation for entering and updating information, especially for calculation fields.
• **Role-Based Views:** Different views or permissions for sales team members, managers, and administrators.

# 3. Non-Functional Requirements

## 3.1 Performance & Scalability

• **Speed:** The system must retrieve and process large datasets quickly.
• **Concurrency:** Support simultaneous access by multiple users.
• **Scalability:** Ability to handle growth in the number of transactions, customer records, and services.

## 3.2 Security & Access Control

• **Role-Based Access Control:** Implement secure authentication and authorization so that only authorized users can access or modify data.
• **Data Encryption:** Encrypt sensitive data both at rest and in transit.
• **Audit Logging:** Log all user actions for security reviews and compliance purposes.

## 3.3 Availability & Reliability

• **Centralized Hosting:** Consider cloud deployment or an on-premise server solution to ensure high availability and centralized access.
• **Backup & Recovery:** Ensure regular backups, disaster recovery plans, and data redundancy.
• **Robust Error Handling:** Provide clear error messages and failover mechanisms to prevent data loss.

## 3.4 Maintainability & Extensibility

• **Modular Architecture:** Use a design that supports future enhancements or additional modules.
• **Integration Capabilities:** Be ready to integrate with other systems (CRM, ERP, Business Intelligence tools) via APIs or other connectors.
• **Documentation & Support:** Detailed system documentation, including user guides and technical specs, to facilitate long-term maintenance.

# 4. Data Migration & Integration

• **Data Import:** Build a migration tool that can map the existing Excel fields to the new system's database schema.
• **Validation & Testing:** Implement checks to ensure data integrity during migration.
• **Integration Points:** Identify other systems that might need to share data (e.g., Salesforce, accounting systems) and design secure API endpoints or data export functionalities.

# 5. Technology Considerations

• **Database System:** Choose a relational database (e.g., PostgreSQL, MySQL, SQL Server) that supports structured query languages and ACID transactions, or a hybrid solution if some semi-structured data is expected.
• **Application Framework:** Consider web frameworks (e.g., Django, Ruby on Rails, or Node.js-based frameworks) for ease of development and rapid prototyping.
• **Cloud vs. On-Premise:** Evaluate whether a cloud-based solution (e.g., AWS, Azure, or Google Cloud) or on-premise infrastructure best suits our accessibility, security, and scalability needs.
• **API-First Approach:** Design the system with APIs in mind to allow third-party integrations, custom reports, and mobile app development.

# 6. Future Enhancements

• **AI & Predictive Analytics:** Incorporate machine learning modules to forecast revenue, predict renewals, and analyze customer behavior.
• **Mobile Application:** Develop a mobile app version for on-the-go access by sales representatives.
• **Custom Workflow Automation:** Further automate sales processes, including contract renewals and cross-department notifications.

# 7. Summary

The new system should overcome the limitations of an Excel-based solution by:

• Centralizing data in a secure, scalable, and fast database.
• Providing multi-user access with robust role-based security.
• Enabling dynamic calculations and comprehensive reporting.
• Integrating easily with existing systems and supporting future enhancements.

With these comprehensive requirements, we can proceed to design a system that serves our sales operations reliably while offering future growth potential and improved user experience.
