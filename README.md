# budgetApp

Mint-esque app using Sinatra and Highcharts for visualizing spending & earning data.

###Graphs
Bar graph displays a stacked 12-month span of spending data. Currently only displays receipts classified as 'costs' and under the 'general' funding category - everyday spending.

Todo:
  - Add filters for funding sources
  - Add drilldown to break down categories further
  - Allow date range selection

###Receipts
Input interface for individual transactions. Includes dropdowns for 'item' and 'method' columns based on what the user has added to the corresponding lists. If an entry is made that is a duplicate of a previous entry (date, amount and item are the same) the item will not be saved again.
Todo:
  - Add dialog for when item is not saved because of duplication - check whether to save duplicate.
  - ~~Add primary keys so entries can be deleted or updated.~~
  - ~~Add filtering~~

###Items & Categories
Interface for adding custom categories and sub-categories. The items will be options in the receipt form dropdown for 'item', and the categories will be used as the primary grouping in the bar graphs.
Todo:
  - Drag-and-drop ordering

###Methods
Interface for adding payment methods. These items are the options for the 'method' dropdown in the receipt form.
Todo:
   - Add methods table
   - Connect to accounts for checking balances?
