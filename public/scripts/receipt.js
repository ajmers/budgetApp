$(function(){

    //Receipt model - has date, amount, name, description, item, method, funding, expense, envelope, roommate, notes, tag and id columsn.

    window.Receipt = Backbone.Model.extend({
        idAttribute: "id",
        defaults:  {
            funding: 'General',
            expense: 'Personal',
        },
    });

    window.Filter = Backbone.Model.extend({
        idAttribute: "id"
    });


    window.ReceiptList = Backbone.Collection.extend({
        model: Receipt,
        pageNumber:1,

        fetchNewItems: function () {
            if (Receipts.models.length >= 50) {
                this.pageNumber++;
            }
            this.fetch({data: {page: this.pageNumber,
                                filters: this.filters}});
        },
        fetchOnScroll: function(ev) {
            if ((window.innerHeight + window.scrollY) >=
                    document.body.offsetHeight) {
                this.fetchNewItems();
            }
        },
        filters: {},
        attrFilter: function(attr, value) {
            filtered = this.filter(function(receipt) {
                return receipt.get(attr) === value;
            });

            $('table#items tbody.data').empty();
            Receipts.reset();
            Receipts.add(filtered);
            if (!Receipts.filters[attr] || this.filters[attr] != value) {
                this.filters[attr] = value;
            }
        },
        comparator: function(m) {
            return -(new Date(m.get('date')));
        },

        url: '/api/receipts'
    });


    window.Receipts = new ReceiptList;

    window.RowEditor = Backbone.View.extend({
        tagName: 'div',
        template: _.template($('#editor-template').html()),
        events: {
            'submit form#update' : 'updateReceipt',
            'keyup' : 'escape'
        },
        initialize: function() {
            this.model.bind('change', this.render, this);
            this.model.bind('destroy', this.remove, this);
        },
        escape: function(ev) {
            if(ev.which == 27){
                this.$el.remove();
            }
        },
        render: function() {
            $(this.el).html(this.template(this.model.toJSON));
            this.setValues();
            return this;
        },
        setValues: function() {
            var that = this;
            this.$('input, select').each(function(i) {
                if (this.type !== 'submit') {
                    if (this.name === 'amount') {
                        this.value = parseFloat(that.model.get(this.name), 10);
                    } else {
                        this.value = that.model.get(this.name);
                    }
                }
            });
        },

        updateReceipt: function(ev) {
            var that = this;
            ev.preventDefault();
            var data = {};
            for (var i = 0, len = ev.target.length; i < len; i++) {
                var field = ev.target[i];
                if (field.value) {
                    data[field.name] = field.value;
                }
            }
            this.model.set(data);
            this.model.save(null, {patch: true,
                success: function(model, response) {
                    that.$el.remove();
                }
            });
            return false;
        }
        });

    window.FilterView = Backbone.View.extend({
        tagName: 'div',
        template: _.template($('#filter-template').html()),
        initialize: function() {
            this.model.bind('change', this.render, this);
            this.model.bind('destroy', this.remove, this);
        },
        render: function() {
            $(this.el).html(this.template(this.model.toJSON));
            this.setText();
            return this;
        },
        events: {
            "click span.delete" : "clear"
        },

        remove: function() {
            $(this.el).remove();
        },

        clear: function() {
            delete Receipts.filters[this.model.get('name')];
            this.model.destroy();
            Receipts.fetchNewItems();
        },

        setText: function() {
            this.$('div.name span.name').html(this.model.get('name'));
            this.$('div.value').html(this.model.get('value'));
        },
    });

    window.ReceiptView = Backbone.View.extend({
        tagName: 'tr',
        template: _.template($('#row-template').html()),
        initialize: function() {
            this.model.bind('change', this.render, this);
            this.model.bind('destroy', this.remove, this);
        },
        events: {
            "click div.edit.show-edit" : "edit",
            "click td.delete" : "clear",
            "mouseenter td" : "showTools",
            "mouseleave td" : "hideTools",
            "click .filter" : "filter"
        },

        edit: function() {
            var view = new RowEditor({model: this.model});
            this.$el.before(view.render().el);
        },

        showTools: function(ev) {
            $('span.filter', ev.target).addClass('show-filter');
            $('div.edit', this.el).addClass('show-edit');
        },

        hideTools: function(ev) {
            $('span.filter', ev.target).removeClass('show-filter');
            $('div.edit', this.el).removeClass('show-edit');
        },

        filter: function(ev) {
            var text = $.trim(ev.target.parentNode.textContent);
            var colName = ev.target.parentNode.className;
            var filter = new window.Filter({name: colName, value: text});
            Receipts.attrFilter(colName, text);
            App.addFilter(filter);
        },

        render: function() {
            $(this.el).html(this.template(this.model.toJSON()));
            this.setText();
            return this;
        },

        remove: function() {
            $(this.el).remove();
        },

        setText: function() {
            this.$('td.date').prepend(this.model.get('date'));
            this.$('td.amount').prepend(parseFloat(this.model.get('amount')));
            this.$('td.name').prepend(this.model.get('name'));
            this.$('td.description').prepend(this.model.get('description'));
            this.$('td.item').prepend(this.model.get('item'));
            this.$('td.method').prepend(this.model.get('method'));
            this.$('td.funding').prepend(this.model.get('funding'));
            this.$('td.expense').prepend(this.model.get('expense'));
            this.$('td.envelope').prepend(this.model.get('envelope'));
            this.$('td.roommate').prepend(this.model.get('roommate'));
            this.$('td.notes').prepend(this.model.get('notes'));
            this.$('td.tag').prepend(this.model.get('tag'));
        },

        clear: function() {
            this.model.destroy();
        }
    });


    window.AppView = Backbone.View.extend({
        el: $('#budgetApp'),
        initialize: function() {
            Receipts.bind('add', this.addOne, this);
            Receipts.bind('all', this.render, this);
            $(window).bind('scroll', function(ev) {
                Receipts.fetchOnScroll(ev);
            });
          Receipts.fetchNewItems();
        },

        events: {
            "submit form#new" : "createReceipt",
            "click a#load-more-button" : "fetchNewItems"
        },

        fetchNewItems: function(ev) {
            Receipts.fetchNewItems();
        },

        createReceipt: function(ev) {
            ev.preventDefault();
            var data = {};
            for (var i = 0, len = ev.target.length; i < len; i++) {
                var field = ev.target[i];
                if (field.value) {
                    data[field.name] = field.value;
                }
            }
            data.new = true;
            Receipts.create(data);
            ev.target.reset();
            this.$('input[name="date"]').focus();
            return false;
        },

        addFilter: function(filter) {
            var view = new FilterView({model: filter});
            this.$('div#filters').append(view.render().el);
        },

        addOne: function(receipt) {
            var view = new ReceiptView({model: receipt});
            if (receipt.get('new')) {
                this.$('table#items tbody.new').append(view.render().el);
            } else {
                this.$('table#items tbody.data').append(view.render().el);
            }
        },

        addAll: function() {
            Receipts.each(this.addOne);
        }
    });
    window.App = new AppView;
});
