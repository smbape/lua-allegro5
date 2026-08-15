class ForStatement {
    constructor({
        identifier,
        open,
        initialization,
        initsemi,
        condition,
        condsemi,
        afterthought,
        close,
        statement
    }, loc) {
        this.identifier = identifier;
        this.open = open;
        this.initialization = initialization;
        this.initsemi = initsemi;
        this.condition = condition;
        this.condsemi = condsemi;
        this.afterthought = afterthought;
        this.close = close;
        this.statement = statement;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        this.identifier.visit(cb, parents);
        this.open.visit(cb, parents);

        if (this.initialization) {
            this.initialization.visit(cb, parents);
        }

        this.initsemi.visit(cb, parents);

        if (this.condition) {
            this.condition.visit(cb, parents);
        }

        this.condsemi.visit(cb, parents);

        if (this.afterthought) {
            this.afterthought.visit(cb, parents);
        }

        this.close.visit(cb, parents);
        this.statement.visit(cb, parents);

        parents.pop();
        cb(this, parents);
    }
}

exports.ForStatement = ForStatement;
