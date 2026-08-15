class IfStatement {
    constructor({
        identifier,
        condition,
        statement,
        elsekw,
        alternative
    }, loc) {
        this.identifier = identifier;
        this.condition = condition;
        this.statement = statement;
        this.elsekw = elsekw;
        this.alternative = alternative;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        this.identifier.visit(cb, parents);
        this.condition.visit(cb, parents);
        this.statement.visit(cb, parents);

        if (this.alternative) {
            this.elsekw.visit(cb, parents);
            this.alternative.visit(cb, parents);
        }

        parents.pop();
        cb(this, parents);
    }
}

exports.IfStatement = IfStatement;
