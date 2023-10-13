function [has_column] = tableHasColumn(my_table, column_name)

has_column = strcmp(column_name, my_table.Properties.VariableNames);

end 