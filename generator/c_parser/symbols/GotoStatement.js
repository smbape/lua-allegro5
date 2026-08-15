class GotoStatement {
    constructor({
        goto,
        identifier,
        semicolon
    }, loc) {
        this.goto = goto;
        this.identifier = identifier;
        this.semicolon = semicolon;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        this.goto.visit(cb, parents);
        this.identifier.visit(cb, parents);
        this.semicolon.visit(cb, parents);

        parents.pop();
        cb(this, parents);
    }
}

exports.GotoStatement = GotoStatement;
