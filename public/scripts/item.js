$(function(){

    window.Item = Backbone.Model.extend({
        idAttribute: "name"
    });

    window.ItemList = Backbone.Collection.extend({
        model: Item,
        pageNumber:0,

        fetchNewItems: function () {
            this.pageNumber++;
            this.fetch({data: {page: this.pageNumber}});
        },

        fetchOnScroll: function(ev) {
            if ((window.innerHeight + window.scrollY) >=
                    document.body.offsetHeight) {
                this.fetchNewItems();
            }
        },

        url: '/api/items',

    });


    window.Items = new ItemList;

    window.ItemView = Backbone.View.extend({
        tagName: 'tr',
        template: _.template($('#row-template').html()),
        initialize: function() {
            this.model.bind('change', this.render, this);
            this.model.bind('destroy', this.remove, this);
        },
        events: {
            "click td.delete" : "clear",
        //    "click .filter" : "filter"
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
            this.$('td.item').prepend(this.model.get('item'));
            this.$('td.category').prepend(this.model.get('category'));
            this.$('td.recurring').prepend(this.model.get('recurring'));
            this.$('td.order').prepend(this.model.get('order'));
        },

        clear: function() {
            this.model.destroy();
        }
    });


    window.AppView = Backbone.View.extend({
        el: $('#budgetApp'),
        initialize: function() {
            Items.bind('add', this.addOne, this);
            Items.bind('all', this.render, this);
            Items.fetchNewItems();
            this.rollUpForm();
        },

        events: {
            "submit form#new" : "createItem",
            "click #form-container .collapse" : "rollUpForm"
        },

        rollUpForm: function(ev) {
            var form = this.$('form#new');
            form.animate({'height': 'toggle'}, 200);
        },

        createItem: function(ev) {
            ev.preventDefault();
            var data = {};
            for (var i = 0, len = ev.target.length; i < len; i++) {
                var field = ev.target[i];
                if (field.value) {
                    data[field.name] = field.value;
                }
            }
            data.new = true;
            Items.create(data);
            ev.target.reset();
            this.$('input[name="name"]').focus();
            return false;
        },

        addOne: function(item) {
            var view = new ItemView({model: item});
            if (item.get('new')) {
                this.$('table#items tbody.new').append(view.render().el);
            } else {
                this.$('table#items tbody.data').append(view.render().el);
            }
        },

        addAll: function() {
            Items.each(this.addOne);
        }
    });
    window.App = new AppView;
});
