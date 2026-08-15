class DoWhileStatement {
    constructor({
        dokw,
        statement,
        identifier,
        condition,
        semicolon
    }, loc) {
        this.dokw = dokw;
        this.statement = statement;
        this.identifier = identifier;
        this.condition = condition;
        this.semicolon = semicolon;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        this.dokw.visit(cb, parents);
        this.statement.visit(cb, parents);
        this.identifier.visit(cb, parents);
        this.condition.visit(cb, parents);
        this.semicolon.visit(cb, parents);

        parents.pop();
        cb(this, parents);
    }
}

exports.DoWhileStatement = DoWhileStatement;
