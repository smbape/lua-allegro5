class WhileStatement {
    constructor({
        identifier,
        condition,
        statement
    }, loc) {
        this.identifier = identifier;
        this.condition = condition;
        this.statement = statement;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        this.identifier.visit(cb, parents);
        this.condition.visit(cb, parents);
        this.statement.visit(cb, parents);

        parents.pop();
        cb(this, parents);
    }
}

exports.WhileStatement = WhileStatement;
